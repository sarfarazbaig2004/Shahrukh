// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ScreensAddProduct extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserRole;
  final String? productId;
  final Map<String, dynamic>? initialData;

  const ScreensAddProduct({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserRole,
    this.productId,
    this.initialData,
  });

  @override
  State<ScreensAddProduct> createState() => _ScreensAddProductState();
}

class _ScreensAddProductState extends State<ScreensAddProduct> {
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isUploadingCatalog = false;

  // --- NEW: Product Nature, Dynamic Hierarchy & Smart Memory ---
  String _productNature = 'Machine';
  String? _machineType;

  // Strict Compatibility for Spares
  String? _compatibleMachineType;

  // Flexible Compatibility for Accessories
  List<String> _compatibleSubcategories = [];

  // Core Compatibility Mapping
  List<String> _compatibleProductIds = [];
  List<String> _compatibleProductNames = [];

  // UOM Smart Memory Data
  List<String> _uomOptions = [
    'Nos.',
    'Set',
    'Pair',
    'Kg',
    'Meter',
    'Feet',
    'Roll',
    'Coil',
    'Litre',
    'Box',
    'Packet',
  ];
  String _selectedUom = 'Nos.';

  // --- NEW: Scope of Supply ---
  List<Map<String, dynamic>> _includedProducts = [];
  // ------------------------------------------------

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hsnController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();

  final _openingStockController = TextEditingController(text: '0');
  final _reorderLevelController = TextEditingController(text: '0');
  final _minStockLevelController = TextEditingController(text: '0');
  final _maxStockLevelController = TextEditingController(text: '0');

  final _costPriceController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _gstController = TextEditingController(text: '18');

  final _makeController = TextEditingController();
  final _notesController = TextEditingController();

  String? _assignedToUid;

  String _productType = 'stock';
  bool _isActive = true;
  bool _trackInventory = true;
  bool _isSaleable = true;
  bool _isPurchasable = true;

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedSubcategoryId;
  String? _selectedSubcategoryName;

  // Multi-file Storage Lists
  List<String> _imageUrls = [];
  List<Map<String, dynamic>> _catalogs = [];

  double _existingStockOnHand = 0;
  double _existingQty = 0;

  bool get isEditMode => widget.productId != null;

  bool get _canAssignOthers =>
      widget.currentUserRole == 'admin' || widget.currentUserRole == 'manager';

  bool get _isServiceLike =>
      _productType == 'service' || _productType == 'non_stock';

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _companyUsersRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users');

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('inventory_categories');

  CollectionReference<Map<String, dynamic>> _subcategoriesRef(
    String categoryId,
  ) => _categoriesRef.doc(categoryId).collection('subcategories');

  CollectionReference<Map<String, dynamic>> get _machineTypesRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('inventory_machine_types');

  // --- CENTRALIZED HELPERS ---
  String _normalizedNature(dynamic value) {
    final natureRaw = (value ?? 'machine').toString().toLowerCase();
    if (natureRaw == 'accessory') return 'Accessory';
    if (natureRaw == 'spare') return 'Spare';
    if (natureRaw == 'consumable') return 'Consumable';
    if (natureRaw == 'raw material' || natureRaw == 'raw_material') {
      return 'Raw Material';
    }
    return 'Machine';
  }

  @override
  void initState() {
    super.initState();

    _assignedToUid = widget.currentUserUid;

    final data = widget.initialData;
    if (data != null) {
      _nameController.text = (data['name'] ?? '').toString();
      _descriptionController.text = (data['description'] ?? '').toString();
      _hsnController.text = (data['hsnCode'] ?? '').toString();
      _itemCodeController.text =
          (data['itemCode'] ??
                  data['productCode'] ??
                  data['code'] ??
                  data['materialCode'] ??
                  data['partNo'] ??
                  '')
              .toString();
      _skuController.text = (data['sku'] ?? '').toString();
      _barcodeController.text = (data['barcode'] ?? '').toString();

      // Legacy fallback for brand mapped to Make
      _makeController.text = (data['make'] ?? data['brand'] ?? '').toString();
      _notesController.text = (data['notes'] ?? '').toString();

      // Secure initialization of legacy UOM mapping
      final uomVal = (data['uom'] ?? 'Nos.').toString();
      if (uomVal.trim().isNotEmpty) {
        _selectedUom = uomVal;
        if (!_uomOptions.contains(_selectedUom)) {
          _uomOptions.add(_selectedUom);
        }
      }

      // Load Product Nature Safely
      _productNature = _normalizedNature(
        data['productNatureLower'] ?? data['productNature'] ?? data['nature'],
      );
      _machineType = data['machineType']?.toString();

      _compatibleMachineType = data['compatibleMachineType']?.toString();

      if (data['compatibleSubcategories'] is List) {
        _compatibleSubcategories = List<String>.from(
          data['compatibleSubcategories'],
        );
      }
      if (data['compatibleProductIds'] is List) {
        _compatibleProductIds = List<String>.from(data['compatibleProductIds']);
      }
      if (data['compatibleProductNames'] is List) {
        _compatibleProductNames = List<String>.from(
          data['compatibleProductNames'],
        );
      }

      // Load Included Products safely
      if (data['includedProducts'] is List) {
        _includedProducts = List<Map<String, dynamic>>.from(
          (data['includedProducts'] as List).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
      }

      // Safely migrate legacy single image OR load new multi-image list
      final existingImages = data['images'];
      if (existingImages is List) {
        _imageUrls = List<String>.from(existingImages);
      } else if ((data['imageUrl'] ?? '').toString().trim().isNotEmpty) {
        _imageUrls = [(data['imageUrl'] ?? '').toString().trim()];
      }

      // Safely migrate legacy single catalog OR load new multi-catalog list
      final existingCatalogs = data['catalogs'];
      if (existingCatalogs is List) {
        _catalogs = (existingCatalogs)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if ((data['catalogUrl'] ?? '').toString().trim().isNotEmpty) {
        _catalogs = [
          {
            'url': (data['catalogUrl'] ?? '').toString().trim(),
            'name': (data['catalogName'] ?? '').toString().trim(),
            'contentType': (data['catalogContentType'] ?? '').toString().trim(),
          },
        ];
      }

      final categoryId = (data['categoryId'] ?? '').toString().trim();
      final categoryName = (data['category'] ?? '').toString().trim();
      final subcategoryId = (data['subcategoryId'] ?? '').toString().trim();
      final subcategoryName = (data['subcategory'] ?? '').toString().trim();

      _selectedCategoryId = categoryId.isEmpty ? null : categoryId;
      _selectedCategoryName = categoryName.isEmpty ? null : categoryName;
      _selectedSubcategoryId = subcategoryId.isEmpty ? null : subcategoryId;
      _selectedSubcategoryName = subcategoryName.isEmpty
          ? null
          : subcategoryName;

      _productType = (data['type'] ?? 'stock').toString();
      _isActive = data['isActive'] == null ? true : data['isActive'] == true;
      _trackInventory = data['trackInventory'] == null
          ? true
          : data['trackInventory'] == true;
      _isSaleable = data['isSaleable'] == null
          ? true
          : data['isSaleable'] == true;
      _isPurchasable = data['isPurchasable'] == null
          ? true
          : data['isPurchasable'] == true;

      final openingStock =
          data['openingStock'] ?? data['stockOnHand'] ?? data['qty'];
      if (openingStock != null) {
        _openingStockController.text = openingStock.toString();
      }

      _existingStockOnHand = _toDouble(data['stockOnHand']);
      _existingQty = _toDouble(data['qty']);

      final reorderLevel = data['reorderLevel'] ?? data['minStockLevel'];
      if (reorderLevel != null) {
        _reorderLevelController.text = reorderLevel.toString();
      }

      final minStockLevel = data['minStockLevel'];
      if (minStockLevel != null) {
        _minStockLevelController.text = minStockLevel.toString();
      }

      final maxStockLevel = data['maxStockLevel'];
      if (maxStockLevel != null) {
        _maxStockLevelController.text = maxStockLevel.toString();
      }

      final costPrice = data['costPrice'];
      if (costPrice != null) {
        _costPriceController.text = costPrice.toString();
      }

      final unitPrice = data['unitPrice'];
      if (unitPrice != null) {
        _unitPriceController.text = unitPrice.toString();
      }

      final mrp = data['mrp'];
      if (mrp != null) {
        _mrpController.text = mrp.toString();
      }

      final gst = data['gstPercentage'];
      if (gst != null) {
        _gstController.text = gst.toString();
      }

      final assigned = (data['assignedToUid'] ?? '').toString();
      if (assigned.isNotEmpty) {
        _assignedToUid = assigned;
      }
    }

    _applyProductTypeRules(silent: true);
    _loadSmartMemoryPrefs();
  }

  Future<void> _loadSmartMemoryPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Custom UOMs
      final customUoms = prefs.getStringList('custom_uoms') ?? [];

      if (!mounted) return;
      setState(() {
        _uomOptions = {
          'Nos.',
          'Set',
          'Pair',
          'Kg',
          'Meter',
          'Feet',
          'Roll',
          'Coil',
          'Litre',
          'Box',
          'Packet',
          ...customUoms,
        }.toList();

        // 2. Load latest UOM memory
        if (!isEditMode) {
          final lastUom = prefs.getString('last_used_product_uom');
          if (lastUom != null && lastUom.isNotEmpty) {
            if (!_uomOptions.contains(lastUom)) {
              _uomOptions.add(lastUom);
            }
            _selectedUom = lastUom;
          }
        } else {
          // Ensure initial Edit mode UOM stays injected
          if (!_uomOptions.contains(_selectedUom)) {
            _uomOptions.add(_selectedUom);
          }
        }

        // 3. Load latest Make/Brand memory (Only auto-fill for new product creations)
        if (!isEditMode && _makeController.text.trim().isEmpty) {
          final lastMake = prefs.getString('last_used_product_make');
          if (lastMake != null && lastMake.isNotEmpty) {
            _makeController.text = lastMake;
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading smart memory prefs: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _hsnController.dispose();
    _itemCodeController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _openingStockController.dispose();
    _reorderLevelController.dispose();
    _minStockLevelController.dispose();
    _maxStockLevelController.dispose();
    _costPriceController.dispose();
    _unitPriceController.dispose();
    _mrpController.dispose();
    _gstController.dispose();
    _makeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyProductTypeRules({bool silent = false}) {
    if (_isServiceLike) {
      _trackInventory = false;
      _openingStockController.text = '0';
      _reorderLevelController.text = '0';
      _minStockLevelController.text = '0';
      _maxStockLevelController.text = '0';
    }
    if (!silent && mounted) {
      setState(() {});
    }
  }

  double _parseDouble(String value, {double fallback = 0}) {
    return double.tryParse(value.trim()) ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  String? _requiredValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _numberValidator(String? v, {bool required = false}) {
    final val = v ?? '';
    if (val.trim().isEmpty && !required) return null;
    if (val.trim().isEmpty && required) return 'Required';
    if (double.tryParse(val.trim()) == null) return 'Enter valid number';
    return null;
  }

  String? _categoryValidator(String? _) {
    final catId = _selectedCategoryId;
    if (catId == null || catId.trim().isEmpty) {
      return 'Please select category';
    }
    return null;
  }

  String _safeExt(String? ext, {String fallback = 'bin'}) {
    final value = (ext ?? '').trim().toLowerCase();
    if (value.isEmpty) return fallback;
    return value.replaceAll('.', '');
  }

  String _detectContentTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

  IconData _catalogIcon(String? contentType, String? name) {
    final lowerName = (name ?? '').toLowerCase();
    final lowerType = (contentType ?? '').toLowerCase();

    if (lowerType.contains('pdf') || lowerName.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (lowerType.contains('msword') ||
        lowerType.contains('word') ||
        lowerName.endsWith('.doc') ||
        lowerName.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (lowerType.contains('excel') ||
        lowerType.contains('spreadsheet') ||
        lowerName.endsWith('.xls') ||
        lowerName.endsWith('.xlsx')) {
      return Icons.table_chart_outlined;
    }
    if (lowerType.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.attach_file_outlined;
  }

  Future<void> _pickAndUploadImages() async {
    try {
      if (mounted) setState(() => _isUploadingImage = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;

        final ext = _safeExt(file.extension, fallback: 'jpg');
        final contentType = _detectContentTypeFromExtension(ext);
        final fileName =
            'product_photo_${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserUid}_${file.name}';

        final ref = FirebaseStorage.instance.ref().child(
          'companies/${widget.companyId}/products/images/$fileName',
        );

        final metadata = SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'companyId': widget.companyId,
            'uploadedBy': widget.currentUserUid,
            'originalName': file.name,
            'module': 'products',
            'type': 'image',
          },
        );

        final task = await ref
            .putData(bytes, metadata)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw Exception('Upload timed out after 30 seconds'),
            );

        if (task.state != TaskState.success) {
          throw Exception('Image upload did not complete successfully');
        }

        final downloadUrl = await ref.getDownloadURL();

        if (mounted) {
          setState(() {
            _imageUrls.add(downloadUrl);
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product photos uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickAndUploadCatalogs() async {
    try {
      if (mounted) setState(() => _isUploadingCatalog = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'doc',
          'docx',
          'xls',
          'xlsx',
        ],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;

        final ext = _safeExt(file.extension, fallback: 'bin');
        final contentType = _detectContentTypeFromExtension(ext);
        final fileName =
            'product_catalog_${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserUid}_${file.name}';

        final ref = FirebaseStorage.instance.ref().child(
          'companies/${widget.companyId}/products/catalogs/$fileName',
        );

        final metadata = SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'companyId': widget.companyId,
            'uploadedBy': widget.currentUserUid,
            'originalName': file.name,
            'module': 'products',
            'type': 'catalog',
          },
        );

        final task = await ref
            .putData(bytes, metadata)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw Exception('Upload timed out after 30 seconds'),
            );

        if (task.state != TaskState.success) {
          throw Exception('Catalog upload did not complete successfully');
        }

        final downloadUrl = await ref.getDownloadURL();

        if (mounted) {
          setState(() {
            _catalogs.add({
              'url': downloadUrl,
              'name': file.name,
              'contentType': contentType,
            });
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catalogs uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catalog upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCatalog = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  void _removeCatalog(int index) {
    setState(() {
      _catalogs.removeAt(index);
    });
  }

  // ---------------------------------------------------------
  // SECURE NATIVE URL LAUNCHER (BYPASS CORS)
  // ---------------------------------------------------------

  Future<void> _launchSafeUrl(String? urlString) async {
    if (urlString == null || urlString.trim().isEmpty) return;

    final url = urlString.trim();

    if (url.startsWith('gs://')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open gs:// URLs directly.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(url);

      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------

  // --- Dynamic UOM Master ---
  Future<void> _showAddCustomUomDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom UOM'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Unit of Measure',
            hintText: 'e.g. Bundle',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('UOM cannot be empty')),
                );
                return;
              }
              Navigator.pop(ctx, val);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      List<String> customUoms = prefs.getStringList('custom_uoms') ?? [];

      if (!customUoms.any((e) => e.toLowerCase() == result.toLowerCase())) {
        customUoms.add(result);
        await prefs.setStringList('custom_uoms', customUoms);
      }

      setState(() {
        if (!_uomOptions.any((e) => e.toLowerCase() == result.toLowerCase())) {
          _uomOptions.add(result);
        }
        _selectedUom = _uomOptions.firstWhere(
          (e) => e.toLowerCase() == result.toLowerCase(),
          orElse: () => result,
        );
      });
    } else {
      setState(() {}); // refresh visual state if canceled
    }
  }

  Widget _buildUomField() {
    List<DropdownMenuItem<String>> items = _uomOptions
        .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
        .toList();
    items.add(
      const DropdownMenuItem<String>(
        value: 'ADD_NEW_UOM',
        child: Text(
          '+ Add Custom UOM...',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
      ),
    );

    return DropdownButtonFormField<String>(
      value: _selectedUom,
      decoration: _inputDecoration(
        label: 'UOM *',
        icon: Icons.straighten_outlined,
      ),
      items: items,
      validator: _requiredValidator,
      onChanged: (val) {
        if (val == 'ADD_NEW_UOM') {
          _showAddCustomUomDialog();
        } else if (val != null) {
          setState(() {
            _selectedUom = val;
          });
        }
      },
    );
  }

  // --- Dynamic Machine Type Master ---
  Future<void> _showAddMachineTypeDialog(List<String> currentOptions) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Machine Type'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Machine Type Name',
            hintText: 'e.g. Laser Welding Machine',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Name cannot be empty')),
                );
                return;
              }
              final isDup = currentOptions.any(
                (e) => e.toLowerCase() == val.toLowerCase(),
              );
              if (isDup) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Machine type already exists')),
                );
                return;
              }
              Navigator.pop(ctx, val);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _machineTypesRef.add({
          'name': result,
          'nameLower': result.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.currentUserUid,
          'isActive': true,
        });
        setState(() {
          if (_productNature == 'Machine') {
            _machineType = result;
          } else if (_productNature == 'Spare') {
            _compatibleMachineType = result;
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding machine type: $e')),
        );
      }
    } else {
      setState(() {}); // refresh visual state if canceled
    }
  }

  Widget _buildMachineTypeField() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _machineTypesRef.orderBy('nameLower').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Text(
            'Error loading machine types',
            style: TextStyle(color: Colors.red),
          );
        }

        List<String> options = [];
        if (snap.hasData) {
          options = snap.data!.docs
              .map((d) => (d.data()['name'] ?? '').toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        // Keep legacy backward compatibility safe
        if (_machineType != null &&
            _machineType!.isNotEmpty &&
            !options.contains(_machineType)) {
          options.insert(0, _machineType!);
        }

        // Lowercase-safe deduplication (CRITICAL FIX)
        final unique = <String>{};
        options = options.where((e) {
          final lower = e.trim().toLowerCase();
          if (unique.contains(lower)) return false;
          unique.add(lower);
          return true;
        }).toList();

        List<DropdownMenuItem<String?>> items = options
            .map((e) => DropdownMenuItem<String?>(value: e, child: Text(e)))
            .toList();
        items.add(
          const DropdownMenuItem<String?>(
            value: 'ADD_NEW',
            child: Text(
              '+ Add New Machine Type...',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        );

        // Safe Dropdown Value (REMOVED POST FRAME CALLBACK RISK)
        final safeMachineType = options.contains(_machineType)
            ? _machineType
            : null;

        return DropdownButtonFormField<String?>(
          value: safeMachineType,
          decoration: _inputDecoration(
            label: 'Machine Type *',
            icon: Icons.precision_manufacturing_outlined,
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Select Machine Type'),
            ),
            ...items,
          ],
          validator: (val) {
            if (_productNature == 'Machine' &&
                (val == null || val.trim().isEmpty || val == 'ADD_NEW')) {
              return 'Please select machine type';
            }
            return null;
          },
          onChanged: (val) {
            if (val == 'ADD_NEW') {
              _showAddMachineTypeDialog(options);
            } else {
              setState(() {
                _machineType = val;
              });
            }
          },
        );
      },
    );
  }

  // --- NEW: Compatible Subcategories for Accessories ---
  Widget _buildCompatibleSubcategories() {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _subcategoriesRef(
        _selectedCategoryId!,
      ).orderBy('nameLower').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const LinearProgressIndicator();
        }
        if (snap.hasError) return Text('Error: ${snap.error}');

        var docs = snap.data?.docs ?? [];
        docs = docs.where((doc) => doc.data()['isActive'] != false).toList();

        if (docs.isEmpty) {
          return const Text(
            'No subcategories found in selected category',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Supported Machine Categories',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select machine categories this accessory supports',
                style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: docs.map((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString();
                  final isSelected = _compatibleSubcategories.contains(doc.id);

                  return FilterChip(
                    label: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.blue[700] : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.blue[50],
                    checkmarkColor: Colors.blue[700],
                    backgroundColor: const Color(0xFFF9FAFB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.blue.shade200
                            : const Color(0xFFE4E7EC),
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (!_compatibleSubcategories.contains(doc.id)) {
                            _compatibleSubcategories.add(doc.id);
                          }
                        } else {
                          _compatibleSubcategories.remove(doc.id);
                        }
                        _compatibleProductIds.clear();
                        _compatibleProductNames.clear();
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- NEW: Compatible Machine Type Dropdown for Spares ---
  Widget _buildCompatibleMachineTypeField() {
    if (_selectedCategoryId == null || _selectedSubcategoryId == null) {
      return const SizedBox.shrink(); // Hide until subcategory is selected
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _machineTypesRef.orderBy('nameLower').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Text(
            'Error loading machine types',
            style: TextStyle(color: Colors.red),
          );
        }

        List<String> options = [];
        if (snap.hasData) {
          options = snap.data!.docs
              .map((d) => (d.data()['name'] ?? '').toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        if (_compatibleMachineType != null &&
            _compatibleMachineType!.isNotEmpty &&
            !options.contains(_compatibleMachineType)) {
          options.insert(0, _compatibleMachineType!);
        }

        final unique = <String>{};
        options = options.where((e) {
          final lower = e.trim().toLowerCase();
          if (unique.contains(lower)) return false;
          unique.add(lower);
          return true;
        }).toList();

        final safeMachineType = options.contains(_compatibleMachineType)
            ? _compatibleMachineType
            : null;

        List<DropdownMenuItem<String?>> items = [
          const DropdownMenuItem(value: null, child: Text('All Machine Types')),
          ...options.map(
            (e) => DropdownMenuItem<String?>(value: e, child: Text(e)),
          ),
        ];
        items.add(
          const DropdownMenuItem<String?>(
            value: 'ADD_NEW',
            child: Text(
              '+ Add New Machine Type...',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        );

        return DropdownButtonFormField<String?>(
          value: safeMachineType,
          decoration: _inputDecoration(
            label: 'Machine Type Compatibility',
            icon: Icons.precision_manufacturing_outlined,
          ),
          items: items,
          onChanged: (val) {
            if (val == 'ADD_NEW') {
              _showAddMachineTypeDialog(options);
            } else {
              setState(() {
                _compatibleMachineType = val;
                _compatibleProductIds.clear();
                _compatibleProductNames.clear();
              });
            }
          },
        );
      },
    );
  }

  // --- NEW: Scope of Supply (Included Products) ---
  Future<void> _showAddIncludedProductDialog() async {
    String? selectedProductId;
    String? selectedProductName;
    final qtyCtrl = TextEditingController(text: '1');
    String selectedUom =
        _selectedUom; // Default to main product UOM if possible, or 'Nos.'
    String searchQuery = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Add Included Product'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product Search & Selection
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Search Product',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (val) => setDialogState(
                          () => searchQuery = val.toLowerCase(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _productsRef
                              .where('isActive', isEqualTo: true)
                              // Only exclude current product being edited
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                    ConnectionState.waiting &&
                                !snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snap.hasError) {
                              return const Center(
                                child: Text('Error loading products'),
                              );
                            }

                            var docs = snap.data?.docs ?? [];

                            // PROFESSIONAL ERP LOGIC: Scope of Supply should ONLY allow Accessories and Spares
                            final allowed = ['accessory', 'spare'];
                            docs = docs.where((d) {
                              final nature =
                                  (d.data()['productNatureLower'] ?? '')
                                      .toString()
                                      .trim()
                                      .toLowerCase();
                              return allowed.contains(nature);
                            }).toList();

                            // Prevent self-inclusion
                            if (widget.productId != null) {
                              docs = docs
                                  .where((d) => d.id != widget.productId)
                                  .toList();
                            }

                            // Filter by search query
                            if (searchQuery.isNotEmpty) {
                              docs = docs.where((d) {
                                final name = (d.data()['name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final sku =
                                    (d.data()['sku'] ??
                                            d.data()['itemCode'] ??
                                            '')
                                        .toString()
                                        .toLowerCase();
                                return name.contains(searchQuery) ||
                                    sku.contains(searchQuery);
                              }).toList();
                            }

                            // Prevent adding already included products
                            docs = docs
                                .where(
                                  (d) => !_includedProducts.any(
                                    (ip) => ip['productId'] == d.id,
                                  ),
                                )
                                .toList();

                            if (docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No accessory or spare products available',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data();
                                final name = (data['name'] ?? '').toString();
                                final sku =
                                    (data['sku'] ?? data['itemCode'] ?? '')
                                        .toString();
                                final isSelected = selectedProductId == doc.id;

                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.shade50,
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: sku.isNotEmpty
                                      ? Text('SKU: $sku')
                                      : null,
                                  onTap: () {
                                    setDialogState(() {
                                      selectedProductId = doc.id;
                                      selectedProductName = name;
                                      // Suggest UOM if product has one
                                      final pUom = data['uom']?.toString();
                                      if (pUom != null &&
                                          pUom.isNotEmpty &&
                                          _uomOptions.contains(pUom)) {
                                        selectedUom = pUom;
                                      }
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Quantity & UOM
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qtyCtrl,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedUom,
                              decoration: InputDecoration(
                                labelText: 'UOM',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _uomOptions
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedUom = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedProductId == null ||
                        selectedProductName == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a product'),
                        ),
                      );
                      return;
                    }
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Quantity must be greater than 0'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx, {
                      'productId': selectedProductId,
                      'productName': selectedProductName,
                      'qty': qty,
                      'uom': selectedUom,
                    });
                  },
                  child: const Text('Add to Scope'),
                ),
              ],
            );
          },
        );
      },
    );

    // CRITICAL FIX: Ensure valid map is received before saving to state
    if (result != null) {
      setState(() {
        _includedProducts.add(result);
      });
    }
  }

  Widget _buildScopeOfSupply() {
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
                  const Text(
                    'Scope of Supply',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select accessory or spare products included with this machine',
                    style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showAddIncludedProductDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Included Product'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade200),
                ),
              ),
            ],
          ),
          if (_includedProducts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE4E7EC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: IntrinsicColumnWidth(),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE4E7EC)),
                        ),
                      ), // CRITICAL FIX: Proper Border implementation
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Product',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Qty',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'UOM',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Action',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    ..._includedProducts.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(
                          border: idx != _includedProducts.length - 1
                              ? const Border(
                                  bottom: BorderSide(color: Color(0xFFF1F5F9)),
                                )
                              : null, // CRITICAL FIX: Proper Border implementation
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              item['productName'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              item['qty'].toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              item['uom'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _includedProducts.removeAt(idx);
                                });
                              },
                              tooltip: 'Remove',
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
          const SizedBox(height: 12),
          const Text(
            'You can add included products later by editing this machine',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateCard(String title, {String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibleMachines() {
    if (_selectedCategoryId == null || _selectedCategoryId!.trim().isEmpty) {
      return _emptyStateCard('Please select a category first');
    }

    if (_productNature == 'Spare' &&
        (_selectedSubcategoryId == null ||
            _selectedSubcategoryId!.trim().isEmpty)) {
      return _emptyStateCard('Please select a subcategory first');
    }

    if (_productNature == 'Accessory' && _compatibleSubcategories.isEmpty) {
      return _emptyStateCard('Select supported machine categories first');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productsRef
          .where('isActive', isEqualTo: true)
          .where(
            'productNatureLower',
            isEqualTo: 'machine',
          ) // Case-insensitive Machine matching
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.hasError) return Text('Error loading machines: ${snap.error}');

        var docs = snap.data?.docs ?? [];

        // STRICT ERP COMPATIBILITY FILTERING
        docs = docs.where((doc) {
          final data = doc.data();
          final catId = (data['categoryId'] ?? '').toString().trim();
          final subId = (data['subcategoryId'] ?? '').toString().trim();
          final mType = (data['machineType'] ?? data['type'] ?? '')
              .toString()
              .trim();

          if (catId != _selectedCategoryId) return false;

          if (_productNature == 'Spare') {
            if (subId != _selectedSubcategoryId) return false;
            if (_compatibleMachineType != null &&
                _compatibleMachineType!.isNotEmpty) {
              if (mType.toLowerCase() !=
                  _compatibleMachineType!.toLowerCase()) {
                return false;
              }
            }
          } else if (_productNature == 'Accessory') {
            if (!_compatibleSubcategories.contains(subId)) return false;
          }

          return true;
        }).toList();

        // Prevent product from being self-compatible
        if (widget.productId != null) {
          docs = docs.where((e) => e.id != widget.productId).toList();
        }

        docs.sort(
          (a, b) => (a.data()['name'] ?? '').toString().toLowerCase().compareTo(
            (b.data()['name'] ?? '').toString().toLowerCase(),
          ),
        );

        if (docs.isEmpty) {
          return _emptyStateCard(
            'No compatible machines available yet',
            subtitle: 'Create machine products first or link them later',
          );
        }

        final titleLabel = _productNature == 'Accessory'
            ? 'Supported Machines'
            : 'Compatible Machines';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Showing machines based on compatibility filters',
                style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: docs.map((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString();
                  final isSelected = _compatibleProductIds.contains(doc.id);

                  return FilterChip(
                    label: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.blue[700] : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.blue[50],
                    checkmarkColor: Colors.blue[700],
                    backgroundColor: const Color(0xFFF9FAFB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.blue.shade200
                            : const Color(0xFFE4E7EC),
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (!_compatibleProductIds.contains(doc.id)) {
                            _compatibleProductIds.add(doc.id);
                          }
                          if (!_compatibleProductNames.contains(name)) {
                            _compatibleProductNames.add(name);
                          }
                        } else {
                          // Safe mapping removal
                          _compatibleProductIds.remove(doc.id);
                          _compatibleProductNames.remove(name);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can link compatible machines later by editing this product',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagesPreview() {
    if (_imageUrls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final url = _imageUrls[index];
          return Container(
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            size: 30,
                            color: Colors.green,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Uploaded',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () => _launchSafeUrl(url),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.zoom_in, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'View',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCatalogsPreview() {
    if (_catalogs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: _catalogs.asMap().entries.map((entry) {
        final index = entry.key;
        final cat = entry.value;
        final url = (cat['url'] ?? '').toString();
        final name = (cat['name'] ?? 'Document').toString();
        final type = (cat['contentType'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(_catalogIcon(type, name), color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ready to view',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _launchSafeUrl(url),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open', style: TextStyle(fontSize: 12)),
              ),
              IconButton(
                onPressed: () => _removeCatalog(index),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageAndCatalogCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Product Media & Notes'),

          // Image Upload Section
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Images',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload one or multiple images.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isUploadingImage
                          ? null
                          : _pickAndUploadImages,
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _isUploadingImage ? 'Uploading...' : 'Add Images',
                      ),
                    ),
                  ],
                ),
                if (_imageUrls.isNotEmpty) const SizedBox(height: 16),
                _buildImagesPreview(),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Catalog Upload Section
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Catalogs & Attachments',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload PDFs, brochures, or spec sheets.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isUploadingCatalog
                          ? null
                          : _pickAndUploadCatalogs,
                      icon: _isUploadingCatalog
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file_outlined),
                      label: Text(
                        _isUploadingCatalog ? 'Uploading...' : 'Add Catalogs',
                      ),
                    ),
                  ],
                ),
                if (_catalogs.isNotEmpty) const SizedBox(height: 16),
                _buildCatalogsPreview(),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _buildTextField(
            controller: _notesController,
            label: 'Internal Notes',
            icon: Icons.sticky_note_2_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    final state = _formKey.currentState;
    if (state == null || !state.validate()) return;

    final assigned = _assignedToUid;
    if (assigned == null || assigned.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select assigned user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final catId = _selectedCategoryId;
    final catName = _selectedCategoryName;
    if (catId == null || catName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final openingStock = _trackInventory && !_isServiceLike
          ? _parseDouble(_openingStockController.text)
          : 0.0;

      final reorderLevel = _trackInventory && !_isServiceLike
          ? _parseDouble(_reorderLevelController.text)
          : 0.0;

      final minStockLevel = _trackInventory && !_isServiceLike
          ? _parseDouble(_minStockLevelController.text)
          : 0.0;

      final maxStockLevel = _trackInventory && !_isServiceLike
          ? _parseDouble(_maxStockLevelController.text)
          : 0.0;

      final costPrice = _parseDouble(_costPriceController.text);
      final unitPrice = _parseDouble(_unitPriceController.text);
      final mrp = _parseDouble(_mrpController.text);
      final gst = _parseDouble(_gstController.text);

      final cleanName = _nameController.text.trim();
      final cleanDescription = _descriptionController.text.trim();
      final cleanHsn = _hsnController.text.trim();
      final cleanItemCode = _itemCodeController.text.trim();
      if (cleanItemCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item Code is required for quotation PDF.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final cleanSku = _skuController.text.trim();
      final cleanBarcode = _barcodeController.text.trim();
      final cleanMake = _makeController.text.trim();
      final cleanNotes = _notesController.text.trim();

      final data = <String, dynamic>{
        'companyId': widget.companyId,
        'productNature': _productNature, // Saved for backward compat
        'productNatureLower': _productNature.toLowerCase(),
        if (_productNature == 'Machine') 'machineType': _machineType ?? '',
        if (_productNature == 'Machine')
          'machineTypeLower': (_machineType ?? '').toLowerCase(),
        if (_productNature == 'Machine') 'includedProducts': _includedProducts,

        if (_productNature == 'Spare')
          'compatibleMachineType': _compatibleMachineType ?? '',
        if (_productNature == 'Accessory')
          'compatibleSubcategories': _compatibleSubcategories,

        if (_productNature == 'Accessory' || _productNature == 'Spare')
          'compatibleProductIds': _compatibleProductIds,
        if (_productNature == 'Accessory' || _productNature == 'Spare')
          'compatibleProductNames': _compatibleProductNames,
        'name': cleanName,
        'nameLower': cleanName.toLowerCase(),
        'description': cleanDescription,
        'type': _productType,
        'categoryId': catId,
        'category': catName,
        'subcategoryId': _selectedSubcategoryId,
        'subcategory': _selectedSubcategoryName ?? '',
        'make': cleanMake,
        'brand':
            cleanMake, // Ensure backward compatibility with legacy 'brand' query dependencies
        'hsnCode': cleanHsn,
        'itemCode': cleanItemCode,
        'sku': cleanSku,
        'barcode': cleanBarcode,
        'uom': _selectedUom,
        'openingStock': openingStock,
        'reorderLevel': reorderLevel,
        'minStockLevel': minStockLevel,
        'maxStockLevel': maxStockLevel,
        'trackInventory': _trackInventory,
        'costPrice': costPrice,
        'unitPrice': unitPrice,
        'sellingPrice': unitPrice,
        'mrp': mrp,
        'gstPercentage': gst,
        // Ensure backward compatibility while adopting new List structures
        'imageUrl': _imageUrls.isNotEmpty ? _imageUrls.first : '',
        'images': _imageUrls,
        'catalogUrl': _catalogs.isNotEmpty ? _catalogs.first['url'] : '',
        'catalogName': _catalogs.isNotEmpty ? _catalogs.first['name'] : '',
        'catalogContentType': _catalogs.isNotEmpty
            ? _catalogs.first['contentType']
            : '',
        'catalogs': _catalogs,
        'notes': cleanNotes,
        'isActive': _isActive,
        'isSaleable': _isSaleable,
        'isPurchasable': _isPurchasable,
        'assignedToUid': assigned,
        'assignedByUid': widget.currentUserUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.currentUserUid,
        'updatedByUid': widget.currentUserUid,
      };

      if (isEditMode) {
        // Clean stale fields using FieldValue.delete() to avoid leftover data
        if (_productNature != 'Machine') {
          data['machineType'] = FieldValue.delete();
          data['machineTypeLower'] = FieldValue.delete();
          data['includedProducts'] = FieldValue.delete();
        }
        if (_productNature != 'Spare') {
          data['compatibleMachineType'] = FieldValue.delete();
        }
        if (_productNature != 'Accessory') {
          data['compatibleSubcategories'] = FieldValue.delete();
        }
        if (_productNature != 'Accessory' && _productNature != 'Spare') {
          data['compatibleProductIds'] = FieldValue.delete();
          data['compatibleProductNames'] = FieldValue.delete();
        }

        await _productsRef.doc(widget.productId).update({
          ...data,
          'stockOnHand': _trackInventory && !_isServiceLike
              ? _existingStockOnHand
              : 0.0,
          'qty': _trackInventory && !_isServiceLike
              ? (_existingQty == 0 ? _existingStockOnHand : _existingQty)
              : 0.0,
        });
      } else {
        await _productsRef.add({
          ...data,
          'stockOnHand': _trackInventory && !_isServiceLike
              ? openingStock
              : 0.0,
          'qty': _trackInventory && !_isServiceLike ? openingStock : 0.0,
          'isDeleted': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.currentUserUid,
          'createdByUid': widget.currentUserUid,
        });
      }

      // --- SAVE SMART MEMORY STATE ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_used_product_make', cleanMake);
      await prefs.setString('last_used_product_uom', _selectedUom);
      // -------------------------------

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Product updated successfully'
                : 'Product saved successfully',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    void Function(String)? onChanged,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label: label, icon: icon, hint: hint),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label: label, icon: icon),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildAssignUserDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companyUsersRef.where('isActive', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }

        if (snap.hasError) {
          return Text(
            'Failed to load users: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final docs = snap.data?.docs.toList() ?? [];
        docs.sort((a, b) {
          final an = (a.data()['name'] ?? '').toString().toLowerCase();
          final bn = (b.data()['name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

        if (docs.isEmpty) {
          return const Text('No active users found');
        }

        final values = docs.map((e) => e.id).toSet();
        if (_assignedToUid == null || !values.contains(_assignedToUid)) {
          _assignedToUid = docs.first.id;
        }

        return DropdownButtonFormField<String>(
          value: _assignedToUid,
          decoration: _inputDecoration(
            label: 'Assign To',
            icon: Icons.person_outline,
          ),
          items: docs.map((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final role = (data['role'] ?? '').toString();

            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(name.isEmpty ? doc.id : '$name ($role)'),
            );
          }).toList(),
          onChanged: _canAssignOthers
              ? (value) => setState(() => _assignedToUid = value)
              : null,
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: child,
    );
  }

  Widget _buildStatusToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _categoriesRef.orderBy('nameLower').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const LinearProgressIndicator();
        }

        if (snap.hasError) {
          return Text(
            'Failed to load categories: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        var docs = snap.data?.docs ?? [];

        docs = docs.where((doc) {
          final data = doc.data();
          final isActive = data['isActive'] != false;
          final isCurrentSelected = doc.id == _selectedCategoryId;
          return isActive || isCurrentSelected;
        }).toList();

        if (_selectedCategoryId != null &&
            !docs.any((e) => e.id == _selectedCategoryId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedCategoryId = null;
              _selectedCategoryName = null;
              _selectedSubcategoryId = null;
              _selectedSubcategoryName = null;
              _machineType = null;
              _compatibleMachineType = null;
              _compatibleSubcategories.clear();
              _compatibleProductIds.clear();
              _compatibleProductNames.clear();
            });
          });
        }

        return DropdownButtonFormField<String?>(
          value: _selectedCategoryId,
          decoration: _inputDecoration(
            label: 'Category *',
            icon: Icons.folder_outlined,
          ),
          validator: _categoryValidator,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Select Category'),
            ),
            ...docs.map((doc) {
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final active = data['isActive'] != false;
              return DropdownMenuItem<String?>(
                value: doc.id,
                child: Text(active ? name : '$name (Inactive)'),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null || value.isEmpty) {
              setState(() {
                _selectedCategoryId = null;
                _selectedCategoryName = null;
                _selectedSubcategoryId = null;
                _selectedSubcategoryName = null;
                _machineType = null;
                _compatibleMachineType = null;
                _compatibleSubcategories.clear();
                _compatibleProductIds.clear();
                _compatibleProductNames.clear();
              });
              return;
            }

            final selectedDoc = docs.firstWhere((e) => e.id == value);
            setState(() {
              _selectedCategoryId = value;
              _selectedCategoryName = (selectedDoc.data()['name'] ?? '')
                  .toString();
              _selectedSubcategoryId = null;
              _selectedSubcategoryName = null;
              _machineType = null;
              _compatibleMachineType = null;
              _compatibleSubcategories.clear();
              _compatibleProductIds.clear();
              _compatibleProductNames.clear();
            });
          },
        );
      },
    );
  }

  Widget _buildSubcategoryDropdown() {
    if (_productNature == 'Accessory') {
      return const SizedBox.shrink(); // Hide single subcategory dropdown for accessories
    }

    final catId = _selectedCategoryId;
    if (catId == null) {
      return DropdownButtonFormField<String?>(
        value: null,
        decoration: _inputDecoration(
          label: 'Subcategory',
          icon: Icons.folder_open_outlined,
        ),
        items: const [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('Select Category First'),
          ),
        ],
        onChanged: null,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _subcategoriesRef(catId).orderBy('nameLower').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const LinearProgressIndicator();
        }

        if (snap.hasError) {
          return Text(
            'Failed to load subcategories: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        var docs = snap.data?.docs ?? [];

        docs = docs.where((doc) {
          final data = doc.data();
          final isActive = data['isActive'] != false;
          final isCurrentSelected = doc.id == _selectedSubcategoryId;
          return isActive || isCurrentSelected;
        }).toList();

        if (_selectedSubcategoryId != null &&
            !docs.any((e) => e.id == _selectedSubcategoryId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedSubcategoryId = null;
              _selectedSubcategoryName = null;
              _compatibleMachineType = null;
              _compatibleProductIds.clear();
              _compatibleProductNames.clear();
            });
          });
        }

        return DropdownButtonFormField<String?>(
          value: _selectedSubcategoryId,
          decoration: _inputDecoration(
            label: 'Subcategory',
            icon: Icons.folder_open_outlined,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Select Subcategory'),
            ),
            ...docs.map((doc) {
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final active = data['isActive'] != false;
              return DropdownMenuItem<String?>(
                value: doc.id,
                child: Text(active ? name : '$name (Inactive)'),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null || value.isEmpty) {
              setState(() {
                _selectedSubcategoryId = null;
                _selectedSubcategoryName = null;
                _compatibleMachineType = null;
                _compatibleProductIds.clear();
                _compatibleProductNames.clear();
              });
              return;
            }

            final selectedDoc = docs.firstWhere((e) => e.id == value);
            setState(() {
              _selectedSubcategoryId = value;
              _selectedSubcategoryName = (selectedDoc.data()['name'] ?? '')
                  .toString();
              _compatibleMachineType = null;
              _compatibleProductIds.clear();
              _compatibleProductNames.clear();
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditText = isEditMode ? 'Edit Product' : 'Add Product';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(title: Text(isEditText), elevation: 0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 760;

          final mainForm = Form(
            key: _formKey,
            child: Column(
              children: [
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Basic Information'),

                      _buildDropdownField(
                        label: 'Product Nature *',
                        icon: Icons.settings_applications_outlined,
                        value: _productNature,
                        items: const [
                          DropdownMenuItem(
                            value: 'Machine',
                            child: Text('Machine'),
                          ),
                          DropdownMenuItem(
                            value: 'Accessory',
                            child: Text('Accessory'),
                          ),
                          DropdownMenuItem(
                            value: 'Spare',
                            child: Text('Spare'),
                          ),
                          DropdownMenuItem(
                            value: 'Consumable',
                            child: Text('Consumable'),
                          ),
                          DropdownMenuItem(
                            value: 'Raw Material',
                            child: Text('Raw Material'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _productNature = value;
                              if (_productNature != 'Machine') {
                                _machineType = null;
                                _includedProducts.clear();
                              }
                              if (_productNature != 'Spare') {
                                _compatibleMachineType = null;
                              }
                              if (_productNature != 'Accessory') {
                                _compatibleSubcategories.clear();
                              }
                              if (_productNature != 'Accessory' &&
                                  _productNature != 'Spare') {
                                _compatibleProductIds.clear();
                                _compatibleProductNames.clear();
                              }
                              if (_productNature == 'Accessory') {
                                _selectedSubcategoryId = null;
                                _selectedSubcategoryName = null;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _nameController,
                                label: 'Product Name *',
                                icon: Icons.label_outline,
                                validator: _requiredValidator,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Product Type',
                                icon: Icons.category_outlined,
                                value: _productType,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'stock',
                                    child: Text('Stock Item'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'non_stock',
                                    child: Text('Non-Stock Item'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'service',
                                    child: Text('Service'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'raw_material',
                                    child: Text('Raw Material'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'finished_good',
                                    child: Text('Finished Good'),
                                  ),
                                ],
                                onChanged: (value) {
                                  _productType = value ?? 'stock';
                                  _applyProductTypeRules();
                                },
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _nameController,
                          label: 'Product Name *',
                          icon: Icons.label_outline,
                          validator: _requiredValidator,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownField(
                          label: 'Product Type',
                          icon: Icons.category_outlined,
                          value: _productType,
                          items: const [
                            DropdownMenuItem(
                              value: 'stock',
                              child: Text('Stock Item'),
                            ),
                            DropdownMenuItem(
                              value: 'non_stock',
                              child: Text('Non-Stock Item'),
                            ),
                            DropdownMenuItem(
                              value: 'service',
                              child: Text('Service'),
                            ),
                            DropdownMenuItem(
                              value: 'raw_material',
                              child: Text('Raw Material'),
                            ),
                            DropdownMenuItem(
                              value: 'finished_good',
                              child: Text('Finished Good'),
                            ),
                          ],
                          onChanged: (value) {
                            _productType = value ?? 'stock';
                            _applyProductTypeRules();
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(child: _buildCategoryDropdown()),
                            if (_productNature != 'Accessory') ...[
                              const SizedBox(width: 10),
                              Expanded(child: _buildSubcategoryDropdown()),
                            ],
                          ],
                        )
                      else ...[
                        _buildCategoryDropdown(),
                        if (_productNature != 'Accessory') ...[
                          const SizedBox(height: 10),
                          _buildSubcategoryDropdown(),
                        ],
                      ],

                      // --- DYNAMIC FIELDS START ---
                      if (_productNature == 'Machine') ...[
                        const SizedBox(height: 10),
                        _buildMachineTypeField(),
                        const SizedBox(height: 10),
                        _buildScopeOfSupply(),
                      ],

                      if (_productNature == 'Accessory') ...[
                        const SizedBox(height: 10),
                        _buildCompatibleSubcategories(),
                        const SizedBox(height: 10),
                        _buildCompatibleMachines(),
                      ],

                      if (_productNature == 'Spare') ...[
                        const SizedBox(height: 10),
                        _buildCompatibleMachineTypeField(),
                        const SizedBox(height: 10),
                        _buildCompatibleMachines(),
                      ],

                      // --- DYNAMIC FIELDS END ---
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _makeController,
                        label: 'Make',
                        icon: Icons.workspace_premium_outlined,
                        hint: 'e.g. MEMCO',
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Codes & Classification'),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _hsnController,
                                label: 'HSN / SAC Code *',
                                icon: Icons.confirmation_number_outlined,
                                validator: _requiredValidator,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _itemCodeController,
                                label: 'Item Code *',
                                icon: Icons.code_outlined,
                                validator: _requiredValidator,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _hsnController,
                          label: 'HSN / SAC Code *',
                          icon: Icons.confirmation_number_outlined,
                          validator: _requiredValidator,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _itemCodeController,
                          label: 'Item Code *',
                          icon: Icons.code_outlined,
                          validator: _requiredValidator,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _skuController,
                                label: 'SKU',
                                icon: Icons.tag_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _barcodeController,
                                label: 'Barcode',
                                icon: Icons.qr_code_scanner_outlined,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _skuController,
                          label: 'SKU',
                          icon: Icons.tag_outlined,
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _barcodeController,
                          label: 'Barcode',
                          icon: Icons.qr_code_scanner_outlined,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildUomField(), // Replaced UOM Text Field with Dynamic Standard UOM Field
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Inventory Controls'),
                      _buildStatusToggleTile(
                        title: 'Track Inventory',
                        subtitle:
                            'Enable quantity and stock-related control for this item.',
                        value: _trackInventory,
                        onChanged: _isServiceLike
                            ? (_) {}
                            : (value) {
                                setState(() {
                                  _trackInventory = value;
                                  if (!value) {
                                    _openingStockController.text = '0';
                                    _reorderLevelController.text = '0';
                                    _minStockLevelController.text = '0';
                                    _maxStockLevelController.text = '0';
                                  }
                                });
                              },
                      ),
                      if (_isServiceLike)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Inventory tracking is disabled automatically for service and non-stock items.',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _openingStockController,
                                label: 'Opening Stock',
                                icon: Icons.production_quantity_limits_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    _trackInventory && !_isServiceLike
                                    ? _numberValidator(v)
                                    : null,
                                onChanged: (_) => setState(() {}),
                                enabled: _trackInventory && !_isServiceLike,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _reorderLevelController,
                                label: 'Reorder Level',
                                icon: Icons.warning_amber_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    _trackInventory && !_isServiceLike
                                    ? _numberValidator(v)
                                    : null,
                                onChanged: (_) => setState(() {}),
                                enabled: _trackInventory && !_isServiceLike,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _openingStockController,
                          label: 'Opening Stock',
                          icon: Icons.production_quantity_limits_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _trackInventory && !_isServiceLike
                              ? _numberValidator(v)
                              : null,
                          onChanged: (_) => setState(() {}),
                          enabled: _trackInventory && !_isServiceLike,
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _reorderLevelController,
                          label: 'Reorder Level',
                          icon: Icons.warning_amber_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _trackInventory && !_isServiceLike
                              ? _numberValidator(v)
                              : null,
                          onChanged: (_) => setState(() {}),
                          enabled: _trackInventory && !_isServiceLike,
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _minStockLevelController,
                                label: 'Minimum Stock',
                                icon: Icons.vertical_align_bottom_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    _trackInventory && !_isServiceLike
                                    ? _numberValidator(v)
                                    : null,
                                enabled: _trackInventory && !_isServiceLike,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _maxStockLevelController,
                                label: 'Maximum Stock',
                                icon: Icons.vertical_align_top_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    _trackInventory && !_isServiceLike
                                    ? _numberValidator(v)
                                    : null,
                                enabled: _trackInventory && !_isServiceLike,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _minStockLevelController,
                          label: 'Minimum Stock',
                          icon: Icons.vertical_align_bottom_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _trackInventory && !_isServiceLike
                              ? _numberValidator(v)
                              : null,
                          enabled: _trackInventory && !_isServiceLike,
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _maxStockLevelController,
                          label: 'Maximum Stock',
                          icon: Icons.vertical_align_top_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _trackInventory && !_isServiceLike
                              ? _numberValidator(v)
                              : null,
                          enabled: _trackInventory && !_isServiceLike,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Pricing & Tax'),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _costPriceController,
                                label: 'Cost Price',
                                icon: Icons.payments_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) => _numberValidator(v),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _unitPriceController,
                                label: 'Selling Price *',
                                icon: Icons.currency_rupee,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    _numberValidator(v, required: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _costPriceController,
                          label: 'Cost Price',
                          icon: Icons.payments_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _numberValidator(v),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _unitPriceController,
                          label: 'Selling Price *',
                          icon: Icons.currency_rupee,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _numberValidator(v, required: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _mrpController,
                                label: 'MRP',
                                icon: Icons.sell_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) => _numberValidator(v),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _gstController,
                                label: 'GST % *',
                                icon: Icons.percent,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) =>
                                    _numberValidator(v, required: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _mrpController,
                          label: 'MRP',
                          icon: Icons.sell_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _numberValidator(v),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _gstController,
                          label: 'GST % *',
                          icon: Icons.percent,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _numberValidator(v, required: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Assignment & Control'),
                      _buildAssignUserDropdown(),
                      if (!_canAssignOthers) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'You can create product only for yourself.',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildStatusToggleTile(
                        title: 'Active Product',
                        subtitle:
                            'Inactive products can be hidden from normal use.',
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                      ),
                      _buildStatusToggleTile(
                        title: 'Saleable',
                        subtitle:
                            'Allow this product to be used in sales and quotations.',
                        value: _isSaleable,
                        onChanged: (value) {
                          setState(() {
                            _isSaleable = value;
                          });
                        },
                      ),
                      _buildStatusToggleTile(
                        title: 'Purchasable',
                        subtitle:
                            'Allow this product to be used in purchase workflows.',
                        value: _isPurchasable,
                        onChanged: (value) {
                          setState(() {
                            _isPurchasable = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildImageAndCatalogCard(),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6EAF0)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveProduct,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : (isEditMode
                                    ? 'Update Product'
                                    : 'Save Product'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: mainForm,
              ),
            ),
          );
        },
      ),
    );
  }
}
