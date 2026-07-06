import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:QUIK/modules/crm/customers/customer_duplicate_helper.dart';
import 'package:QUIK/modules/crm/customers/customer_duplicate_search_service.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_360.dart';
import 'package:QUIK/modules/crm/customers/widgets/customer_duplicate_lookup_field.dart';

// --- PRODUCTION SAFE ID GENERATOR ---
String _generateSecureId() {
  final random = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rndStr = List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  return '${DateTime.now().millisecondsSinceEpoch}-$rndStr';
}

// --- ENTERPRISE GST LOGIC ---
const Map<String, String> _gstStateCodes = {
  '01': 'Jammu and Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab',
  '04': 'Chandigarh', '05': 'Uttarakhand', '06': 'Haryana', '07': 'Delhi',
  '08': 'Rajasthan', '09': 'Uttar Pradesh', '10': 'Bihar', '11': 'Sikkim',
  '12': 'Arunachal Pradesh', '13': 'Nagaland', '14': 'Manipur', '15': 'Mizoram',
  '16': 'Tripura', '17': 'Meghalaya', '18': 'Assam', '19': 'West Bengal',
  '20': 'Jharkhand', '21': 'Odisha', '22': 'Chhattisgarh', '23': 'Madhya Pradesh',
  '24': 'Gujarat', '25': 'Daman and Diu', '26': 'Dadra and Nagar Haveli',
  '27': 'Maharashtra', '28': 'Andhra Pradesh', '29': 'Karnataka', '30': 'Goa',
  '31': 'Lakshadweep', '32': 'Kerala', '33': 'Tamil Nadu', '34': 'Puducherry',
  '35': 'Andaman and Nicobar Islands', '36': 'Telangana', '37': 'Andhra Pradesh',
  '38': 'Ladakh'
};

// --- SAFE BOOLEAN PARSER ---
bool _parseBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is int) return value == 1;
  final str = value.toString().trim().toLowerCase();
  if (str == 'true' || str == '1' || str == 'yes') return true;
  if (str == 'false' || str == '0' || str == 'no') return false;
  return fallback;
}

// --- ENTERPRISE VALIDATORS & NORMALIZERS ---
String _normalizePhone(String phone) {
  return normalizePhone(phone);
}

bool _isValidPan(String pan) {
  return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(pan);
}

bool _isValidGst(String gst) {
  if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(gst)) return false;
  final stateCode = gst.substring(0, 2);
  if (!_gstStateCodes.containsKey(stateCode)) return false;
  final panPart = gst.substring(2, 12);
  if (!_isValidPan(panPart)) return false;
  return true;
}

Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
  final sanitized = <String, dynamic>{};
  payload.forEach((key, value) {
    if (value == null) return;
    if (value is String) {
      final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (trimmed.isNotEmpty) sanitized[key] = trimmed;
    } else if (value is num) {
      if (!value.isNaN && !value.isInfinite) sanitized[key] = value;
    } else if (value is List) {
      final cleanList = value.map((e) {
        if (e is Map<String, dynamic>) return _sanitizePayload(e);
        if (e is String) return e.trim().replaceAll(RegExp(r'\s+'), ' ');
        return e;
      }).where((e) => e != null && (e is! String || e.isNotEmpty)).toList();
      if (cleanList.isNotEmpty) sanitized[key] = cleanList;
    } else if (value is Map<String, dynamic>) {
      final cleanMap = _sanitizePayload(value);
      if (cleanMap.isNotEmpty) sanitized[key] = cleanMap;
    } else {
      sanitized[key] = value;
    }
  });
  return sanitized;
}

int _estimatePayloadSize(Map<String, dynamic> payload) {
  try {
    final testMap = <String, dynamic>{};
    payload.forEach((k, v) {
      if (v is Timestamp || v is FieldValue || v is DateTime) {
        testMap[k] = '';
      } else {
        testMap[k] = v;
      }
    });
    return utf8.encode(jsonEncode(testMap)).length;
  } catch (_) {
    return 0;
  }
}

// --- ENTERPRISE LOGGER ---
void _logError({
  required String module,
  required String method,
  required dynamic error,
  StackTrace? stack,
  required String uid,
}) {
  debugPrint('[$module] ERROR in $method: $error\n$stack');
  try {
    FirebaseFirestore.instance.collection('system_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'module': module,
      'method': method,
      'error': error.toString(),
      'stack': stack?.toString(),
      'uid': uid,
      'type': 'ERROR',
    });
  } catch (_) {}
}

// --- GLOBAL UI HELPERS FOR PERFORMANCE ISOLATION ---
InputDecoration _inputDecoration({required String label, required IconData icon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
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
  String? hint,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  int maxLines = 1,
  void Function(String)? onChanged,
  bool enabled = true,
  TextCapitalization textCapitalization = TextCapitalization.none,
}) {
  return TextFormField(
    controller: controller,
    decoration: _inputDecoration(label: label, icon: icon, hint: hint),
    keyboardType: keyboardType,
    maxLines: maxLines,
    validator: validator,
    onChanged: onChanged,
    enabled: enabled,
    textCapitalization: textCapitalization,
  );
}

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveRow({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

// --- STATE MODEL ---
class _AddressItem {
  final String id;
  DateTime createdAt;
  DateTime updatedAt;
  String createdByUid;
  String updatedByUid;

  String erpAddressCode;
  int version;

  String type;
  final TextEditingController customTypeController;
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController pincodeController;
  final TextEditingController countryController;

  final TextEditingController gstController;
  final TextEditingController contactPersonController;
  final TextEditingController contactPhoneController;
  final TextEditingController contactEmailController;

  List<String> tags;
  bool isPrimary;
  bool isExpanded;
  bool isActive;

  bool isBillingAddress;
  bool isShippingAddress;
  bool isDispatchAddress;
  bool isServiceAddress;

  final TextEditingController tagInputController = TextEditingController();
  final ValueNotifier<String> summaryNotifier = ValueNotifier('');

  late final Map<String, dynamic> _originalState;
  bool _listenersAttached = false;

  _AddressItem({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdByUid = '',
    this.updatedByUid = '',
    this.erpAddressCode = '',
    this.version = 1,
    this.type = 'Head Office',
    String customType = '',
    String street = '',
    String city = '',
    String state = '',
    String pincode = '',
    String country = 'India',
    String gst = '',
    String contactPerson = '',
    String contactPhone = '',
    String contactEmail = '',
    List<String>? tags,
    this.isPrimary = false,
    this.isExpanded = true,
    this.isActive = true,
    this.isBillingAddress = false,
    this.isShippingAddress = false,
    this.isDispatchAddress = false,
    this.isServiceAddress = false,
    bool isExisting = false,
  })  : id = id ?? _generateSecureId(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        tags = tags ?? [],
        customTypeController = TextEditingController(text: customType),
        streetController = TextEditingController(text: street),
        cityController = TextEditingController(text: city),
        stateController = TextEditingController(text: state),
        pincodeController = TextEditingController(text: pincode),
        countryController = TextEditingController(text: country),
        gstController = TextEditingController(text: gst),
        contactPersonController = TextEditingController(text: contactPerson),
        contactPhoneController = TextEditingController(text: contactPhone),
        contactEmailController = TextEditingController(text: contactEmail) {
    _originalState = _captureCurrentState();
    _initListeners();
  }

  Map<String, dynamic> _captureCurrentState() {
    return {
      'type': type,
      'customType': customTypeController.text.trim(),
      'street': streetController.text.trim(),
      'city': cityController.text.trim(),
      'state': stateController.text.trim(),
      'pincode': pincodeController.text.trim(),
      'country': countryController.text.trim(),
      'gst': gstController.text.trim().toUpperCase(),
      'contactPerson': contactPersonController.text.trim(),
      'contactPhone': contactPhoneController.text.trim(),
      'contactEmail': contactEmailController.text.trim(),
      'tags': tags.join(','),
      'isPrimary': isPrimary,
      'isActive': isActive,
      'isBillingAddress': isBillingAddress,
      'isShippingAddress': isShippingAddress,
      'isDispatchAddress': isDispatchAddress,
      'isServiceAddress': isServiceAddress,
    };
  }

  List<String> getModifiedFields() {
    final current = _captureCurrentState();
    final List<String> changed = [];
    current.forEach((key, value) {
      if (_originalState[key] != value) {
        changed.add(key);
      }
    });
    return changed;
  }

  void _initListeners() {
    if (_listenersAttached) return;
    customTypeController.addListener(updateSummary);
    cityController.addListener(updateSummary);
    stateController.addListener(updateSummary);
    countryController.addListener(updateSummary);

    gstController.addListener(_onGstChanged);

    streetController.addListener(_markUpdated);
    cityController.addListener(_markUpdated);
    stateController.addListener(_markUpdated);
    pincodeController.addListener(_markUpdated);
    countryController.addListener(_markUpdated);
    customTypeController.addListener(_markUpdated);
    gstController.addListener(_markUpdated);
    contactPersonController.addListener(_markUpdated);
    contactPhoneController.addListener(_markUpdated);
    contactEmailController.addListener(_markUpdated);

    _listenersAttached = true;
    updateSummary();
  }

  void _onGstChanged() {
    final gst = gstController.text.trim().toUpperCase();
    if (gst.length >= 2) {
      final code = gst.substring(0, 2);
      final state = _gstStateCodes[code];
      if (state != null && stateController.text.trim().isEmpty) {
        stateController.text = state;
        updateSummary(); // Lightweight refresh instead of setState
      }
    }
  }

  void _markUpdated() {
    updatedAt = DateTime.now();
  }

  void updateSummary() {
    final t = type == 'Other'
        ? (customTypeController.text.trim().isNotEmpty ? customTypeController.text.trim() : 'Custom Address')
        : type;
    final loc = [
      cityController.text.trim(),
      stateController.text.trim(),
      countryController.text.trim()
    ].where((e) => e.isNotEmpty).join(', ');

    summaryNotifier.value = loc.isEmpty ? t : '$t • $loc';
  }

  void addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !tags.contains(t)) {
      tags.add(t);
      _markUpdated();
    }
    tagInputController.clear();
  }

  void removeTag(String tag) {
    tags.remove(tag);
    _markUpdated();
  }

  void dispose() {
    if (_listenersAttached) {
      customTypeController.removeListener(updateSummary);
      cityController.removeListener(updateSummary);
      stateController.removeListener(updateSummary);
      countryController.removeListener(updateSummary);
      gstController.removeListener(_onGstChanged);

      streetController.removeListener(_markUpdated);
      cityController.removeListener(_markUpdated);
      stateController.removeListener(_markUpdated);
      pincodeController.removeListener(_markUpdated);
      countryController.removeListener(_markUpdated);
      customTypeController.removeListener(_markUpdated);
      gstController.removeListener(_markUpdated);
      contactPersonController.removeListener(_markUpdated);
      contactPhoneController.removeListener(_markUpdated);
      contactEmailController.removeListener(_markUpdated);
      _listenersAttached = false;
    }

    summaryNotifier.dispose();
    customTypeController.dispose();
    streetController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    countryController.dispose();
    gstController.dispose();
    contactPersonController.dispose();
    contactPhoneController.dispose();
    contactEmailController.dispose();
    tagInputController.dispose();
  }
}

// --- STANDALONE ADDRESS CARD COMPONENT TO PREVENT GLOBAL REBUILDS ---
class _AddressCardWidget extends StatefulWidget {
  final int index;
  final _AddressItem address;
  final bool isDuplicateType;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final VoidCallback onSetPrimary;

  const _AddressCardWidget({
    Key? key,
    required this.index,
    required this.address,
    required this.isDuplicateType,
    required this.onDuplicate,
    required this.onRemove,
    required this.onSetPrimary,
  }) : super(key: key);

  @override
  State<_AddressCardWidget> createState() => _AddressCardWidgetState();
}

class _AddressCardWidgetState extends State<_AddressCardWidget> {

  Widget _buildCheckbox({required String label, required bool value, required ValueChanged<bool?> onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(value: value, onChanged: onChanged, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.address;

    return RepaintBoundary(
      child: Opacity(
        opacity: address.isActive ? 1.0 : 0.65,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: address.isPrimary ? Colors.blue.shade300 : Colors.grey.shade300, width: address.isPrimary ? 1.5 : 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))]
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => address.isExpanded = !address.isExpanded),
                borderRadius: BorderRadius.vertical(top: const Radius.circular(11), bottom: address.isExpanded ? Radius.zero : const Radius.circular(11)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: address.isPrimary ? Colors.blue.shade50.withOpacity(0.4) : Colors.grey.shade50,
                    borderRadius: BorderRadius.vertical(top: const Radius.circular(11), bottom: address.isExpanded ? Radius.zero : const Radius.circular(11)),
                    border: Border(bottom: BorderSide(color: address.isExpanded ? Colors.grey.shade200 : Colors.transparent)),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: widget.index,
                        child: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.drag_indicator, size: 20, color: Colors.grey)),
                      ),
                      Text('Address ${widget.index + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                      if (address.isPrimary) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text('Primary', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
                        ),
                      ],
                      if (!address.isActive) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                          child: Text('Inactive', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: address.summaryNotifier,
                          builder: (context, summary, _) {
                            return Text(
                              summary,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_copy, size: 18),
                        onPressed: widget.onDuplicate,
                        tooltip: 'Duplicate Address',
                        splashRadius: 20,
                      ),
                      Icon(address.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),

              if (address.isExpanded)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isDuplicateType) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade200)),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.amber.shade800),
                              const SizedBox(width: 6),
                              Expanded(child: Text('Multiple "${address.type}" addresses detected.', style: TextStyle(fontSize: 12, color: Colors.amber.shade900))),
                            ],
                          ),
                        ),
                      ],

                      _ResponsiveRow(
                        children: [
                          DropdownButtonFormField<String>(
                            value: address.type,
                            decoration: _inputDecoration(label: 'Address Type *', icon: Icons.bookmark_border_outlined),
                            items: _addressTypeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  address.type = val;
                                  if (val != 'Other') address.customTypeController.clear();
                                  address.updateSummary();
                                });
                              }
                            },
                          ),
                          if (address.type == 'Other')
                            _buildTextField(
                              controller: address.customTypeController,
                              label: 'Custom Type Name *',
                              icon: Icons.edit_outlined,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: address.streetController,
                        label: 'Street Address',
                        icon: Icons.home_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _ResponsiveRow(
                        children: [
                          _buildTextField(
                            controller: address.cityController,
                            label: 'City *',
                            icon: Icons.location_city_outlined,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          _buildTextField(
                            controller: address.stateController,
                            label: 'State',
                            icon: Icons.map_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ResponsiveRow(
                        children: [
                          _buildTextField(
                            controller: address.pincodeController,
                            label: 'Pincode',
                            icon: Icons.markunread_mailbox_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v != null && v.trim().isNotEmpty) {
                                final ctry = address.countryController.text.trim().toLowerCase();
                                if (ctry == 'india' && !RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                                  return 'Invalid Pincode (6 digits)';
                                }
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: address.countryController,
                            label: 'Country *',
                            icon: Icons.public_outlined,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),

                      const Text('Contact & Tax Details (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 12),
                      _ResponsiveRow(
                        children: [
                          _buildTextField(
                            controller: address.contactPersonController,
                            label: 'Contact Person',
                            icon: Icons.person_outline,
                          ),
                          _buildTextField(
                            controller: address.gstController,
                            label: 'Address GST',
                            icon: Icons.receipt_long_outlined,
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ResponsiveRow(
                        children: [
                          _buildTextField(
                            controller: address.contactPhoneController,
                            label: 'Contact Phone',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          _buildTextField(
                            controller: address.contactEmailController,
                            label: 'Contact Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              final email = (v ?? '').trim();
                              if (email.isEmpty) return null;
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Invalid email';
                              return null;
                            },
                          ),
                        ],
                      ),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),

                      const Text('Usage Flags & Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _buildCheckbox(label: 'Billing', value: address.isBillingAddress, onChanged: (v) => setState(() => address.isBillingAddress = v ?? false)),
                          _buildCheckbox(label: 'Shipping', value: address.isShippingAddress, onChanged: (v) => setState(() => address.isShippingAddress = v ?? false)),
                          _buildCheckbox(label: 'Dispatch', value: address.isDispatchAddress, onChanged: (v) => setState(() => address.isDispatchAddress = v ?? false)),
                          _buildCheckbox(label: 'Service', value: address.isServiceAddress, onChanged: (v) => setState(() => address.isServiceAddress = v ?? false)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: address.tagInputController,
                              decoration: _inputDecoration(label: 'Add Tag (e.g. "HQ")', icon: Icons.local_offer_outlined).copyWith(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.add, size: 20),
                                  onPressed: () => setState(() => address.addTag(address.tagInputController.text)),
                                ),
                              ),
                              onFieldSubmitted: (val) => setState(() => address.addTag(val)),
                            ),
                          ),
                        ],
                      ),
                      if (address.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: address.tags.map((tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            onDeleted: () => setState(() => address.removeTag(tag)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: widget.onSetPrimary,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        address.isPrimary ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: address.isPrimary ? Colors.blue.shade700 : Colors.grey.shade500,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Primary',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: address.isPrimary ? FontWeight.w600 : FontWeight.w500,
                                          color: address.isPrimary ? Colors.blue.shade700 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              InkWell(
                                onTap: () => setState(() => address.isActive = !address.isActive),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        address.isActive ? Icons.toggle_on : Icons.toggle_off,
                                        color: address.isActive ? Colors.green.shade600 : Colors.grey.shade500,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        address.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: address.isActive ? FontWeight.w600 : FontWeight.w500,
                                          color: address.isActive ? Colors.green.shade700 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: widget.onRemove,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove Address'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
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
    );
  }
}

class ScreensAddCustomer extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? existingDoc;
  final String companyId;
  final String currentUserUid;
  final String currentUserRole;

  const ScreensAddCustomer({
    super.key,
    this.existingDoc,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserRole,
  });

  @override
  State<ScreensAddCustomer> createState() => _ScreensAddCustomerState();
}

class _ScreensAddCustomerState extends State<ScreensAddCustomer> {
  final _scrollController = ScrollController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();

  final _contactNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();

  final _customerTypeCustomController = TextEditingController();
  final _industryCustomController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_AddressItem> _addresses = [];
  final ValueNotifier<int> _addressListNotifier = ValueNotifier<int>(0);

  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _isLoadingExisting = false;
  Timer? _draftTimer;
  String _saveSessionId = '';
  String _lastSavedDraftHash = '';

  String? _customerCode;
  String? _customerType;
  String? _assignedToUid;
  String? _industry;
  String? _leadSource;
  String? _status;
  String? _priority;
  String? _customerStage;

  String _existingCreatedByUid = '';
  Timestamp? _existingCreatedAt;

  String _currentUserName = '';
  final Map<String, String> _cachedUserNames = {};

  late Stream<QuerySnapshot<Map<String, dynamic>>> _activeUsersStream;
  late final CustomerDuplicateSearchService _liveDuplicateSearchService;

  Map<String, dynamic> _initialCustomerState = {};

  bool get _canAssignOthers {
    final role = widget.currentUserRole.trim().toLowerCase();
    return role == 'director' ||
        role == 'md' ||
        role == 'ceo' ||
        role == 'sales_manager' ||
        role == 'superadmin' ||
        role == 'admin';
  }

  bool get _isEdit => widget.existingDoc != null;

  CollectionReference<Map<String, dynamic>> get _customersCol =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers');

  CollectionReference<Map<String, dynamic>> get _companyUsersCol =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users');

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _notifyAddressChange() {
    _addressListNotifier.value++;
  }

  void _openDuplicateCustomer(CustomerDuplicateSuggestion suggestion) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreensCustomer360(
          customerRef: suggestion.reference,
          companyId: widget.companyId,
          currentUserRole: widget.currentUserRole,
          currentUserName: _currentUserName,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _liveDuplicateSearchService = CustomerDuplicateSearchService(_customersCol);
    _assignedToUid = widget.currentUserUid;
    _status = 'Active';
    _priority = 'Medium';
    _leadSource = 'Direct';
    _customerStage = 'Potential Customer';

    // Store stream reference safely to prevent massive re-renders
    _activeUsersStream = _companyUsersCol.where('isActive', isEqualTo: true).snapshots();

    if (!_isEdit) {
      _loadDraftLocally().then((loaded) {
        if (!loaded && _addresses.isEmpty) {
          _addresses.add(_AddressItem(
            isPrimary: true,
            isBillingAddress: true,
            createdByUid: widget.currentUserUid,
            updatedByUid: widget.currentUserUid,
            erpAddressCode: 'ADDR-001',
          ));
          _notifyAddressChange();
        }
      });
      _draftTimer = Timer.periodic(const Duration(seconds: 15), (_) => _saveDraftLocally());
    } else {
      _loadExistingCustomer();
    }

    _loadCurrentUserName();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _scrollController.dispose();

    _companyController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _businessEmailController.dispose();
    _websiteController.dispose();
    _gstController.dispose();
    _panController.dispose();

    _contactNameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();

    _customerTypeCustomController.dispose();
    _industryCustomController.dispose();
    _notesController.dispose();

    _addressListNotifier.dispose();

    for (final addr in _addresses) {
      addr.dispose();
    }

    super.dispose();
  }

  // --- SMART AUTOSAVE DRAFT LOGIC ---
  Future<void> _saveDraftLocally() async {
    if (_isEdit || _isLoadingExisting || _isSaving) return;
    if (_companyController.text.trim().isEmpty && _phoneController.text.trim().isEmpty && _addresses.length <= 1) return;

    try {
      final draftData = {
        'companyName': _companyController.text,
        'phone': _phoneController.text,
        'altPhone': _altPhoneController.text,
        'email': _businessEmailController.text,
        'website': _websiteController.text,
        'gst': _gstController.text,
        'pan': _panController.text,
        'contactName': _contactNameController.text,
        'designation': _designationController.text,
        'department': _departmentController.text,
        'customerType': _customerType,
        'industry': _industry,
        'leadSource': _leadSource,
        'status': _status,
        'priority': _priority,
        'customerStage': _customerStage,
        'notes': _notesController.text,
        'addresses': _addresses.map((a) => {
          'id': a.id,
          'erpAddressCode': a.erpAddressCode,
          'version': a.version,
          'type': a.type,
          'customType': a.customTypeController.text,
          'street': a.streetController.text,
          'city': a.cityController.text,
          'state': a.stateController.text,
          'pincode': a.pincodeController.text,
          'country': a.countryController.text,
          'gst': a.gstController.text,
          'contactPerson': a.contactPersonController.text,
          'contactPhone': a.contactPhoneController.text,
          'contactEmail': a.contactEmailController.text,
          'tags': a.tags,
          'isActive': a.isActive,
          'isPrimary': a.isPrimary,
          'isBillingAddress': a.isBillingAddress,
          'isShippingAddress': a.isShippingAddress,
          'isDispatchAddress': a.isDispatchAddress,
          'isServiceAddress': a.isServiceAddress,
        }).toList(),
      };

      final currentHash = jsonEncode(draftData);
      if (currentHash == _lastSavedDraftHash) return; // Completely prevents unnecessary disk IO stutters

      _lastSavedDraftHash = currentHash;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_customer_${widget.companyId}', currentHash);
    } catch (_) {}
  }

  Future<bool> _loadDraftLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString('draft_customer_${widget.companyId}');
      if (draftStr != null) {
        final data = jsonDecode(draftStr);
        _lastSavedDraftHash = draftStr;

        _safeSetState(() {
          _companyController.text = data['companyName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _altPhoneController.text = data['altPhone'] ?? '';
          _businessEmailController.text = data['email'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _gstController.text = data['gst'] ?? '';
          _panController.text = data['pan'] ?? '';

          _contactNameController.text = data['contactName'] ?? '';
          _designationController.text = data['designation'] ?? '';
          _departmentController.text = data['department'] ?? '';

          _customerType = data['customerType'];
          _industry = data['industry'];
          _leadSource = data['leadSource'];
          _status = data['status'] ?? 'Active';
          _priority = data['priority'] ?? 'Medium';
          _customerStage = data['customerStage'] ?? 'Potential Customer';
          _notesController.text = data['notes'] ?? '';

          if (data['addresses'] != null) {
            _addresses.clear();
            for (var a in data['addresses']) {
              _addresses.add(_AddressItem(
                id: a['id'],
                erpAddressCode: a['erpAddressCode'] ?? '',
                version: a['version'] ?? 1,
                type: a['type'] ?? 'Head Office',
                customType: a['customType'] ?? '',
                street: a['street'] ?? '',
                city: a['city'] ?? '',
                state: a['state'] ?? '',
                pincode: a['pincode'] ?? '',
                country: a['country'] ?? 'India',
                gst: a['gst'] ?? '',
                contactPerson: a['contactPerson'] ?? '',
                contactPhone: a['contactPhone'] ?? '',
                contactEmail: a['contactEmail'] ?? '',
                tags: List<String>.from(a['tags'] ?? []),
                isActive: _parseBool(a['isActive'], fallback: true),
                isPrimary: _parseBool(a['isPrimary']),
                isBillingAddress: _parseBool(a['isBillingAddress']),
                isShippingAddress: _parseBool(a['isShippingAddress']),
                isDispatchAddress: _parseBool(a['isDispatchAddress']),
                isServiceAddress: _parseBool(a['isServiceAddress']),
                isExpanded: true,
                createdByUid: widget.currentUserUid,
                updatedByUid: widget.currentUserUid,
              ));
            }
            _notifyAddressChange();
          }
        });
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _clearDraftLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_customer_${widget.companyId}');
    } catch (_) {}
  }

  Future<bool> _onWillPop() async {
    if (_isSaving || _isLoadingExisting) return false;

    final hasChanges = _companyController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _addresses.any((a) => a.cityController.text.isNotEmpty);

    if (!hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final doc = await _companyUsersCol.doc(widget.currentUserUid).get();
      final data = doc.data() ?? {};
      _currentUserName = _extractUserName(data, fallbackUid: widget.currentUserUid);
      _safeSetState(() {});
    } catch (_) {}
  }

  String _extractUserName(Map<String, dynamic> data, {required String fallbackUid}) {
    final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? data['userName'] ?? data['email'] ?? '').toString().trim();
    return name.isEmpty ? fallbackUid : name;
  }

  Map<String, dynamic> _captureCustomerCoreState() {
    return {
      'companyName': _companyController.text.trim(),
      'phone': _phoneController.text.trim(),
      'altPhone': _altPhoneController.text.trim(),
      'email': _businessEmailController.text.trim(),
      'website': _websiteController.text.trim(),
      'gst': _gstController.text.trim(),
      'pan': _panController.text.trim(),
      'contactName': _contactNameController.text.trim(),
      'designation': _designationController.text.trim(),
      'department': _departmentController.text.trim(),
      'customerType': _customerType,
      'industry': _industry,
      'leadSource': _leadSource,
      'status': _status,
      'priority': _priority,
      'customerStage': _customerStage,
      'notes': _notesController.text.trim(),
    };
  }

  Future<void> _loadExistingCustomer() async {
    final docRef = widget.existingDoc;
    if (docRef == null) return;

    _safeSetState(() => _isLoadingExisting = true);

    try {
      final snapshot = await docRef.get();
      final data = snapshot.data() ?? {};

      _customerCode = (data['customerCode'] ?? '').toString();
      _companyController.text = (data['companyName'] ?? data['name'] ?? '').toString();
      _phoneController.text = (data['companyPhone'] ?? data['phone'] ?? '').toString();
      _altPhoneController.text = (data['alternatePhone'] ?? '').toString();
      _businessEmailController.text = (data['businessEmail'] ?? data['email'] ?? '').toString();
      _websiteController.text = (data['website'] ?? '').toString();
      _gstController.text = (data['gst'] ?? '').toString();
      _panController.text = (data['pan'] ?? '').toString();

      _contactNameController.text = (data['contactName'] ?? '').toString();
      _designationController.text = (data['designation'] ?? '').toString();
      _departmentController.text = (data['department'] ?? '').toString();

      _addresses.clear();
      final savedAddresses = data['addresses'] as List<dynamic>?;

      if (savedAddresses != null && savedAddresses.isNotEmpty) {
        int index = 0;
        for (final addrData in savedAddresses) {
          index++;
          final map = Map<String, dynamic>.from(addrData as Map);

          final isCustomType = _parseBool(map['isCustomType']);
          final savedType = (map['type'] ?? 'Head Office').toString();

          String resolvedType = 'Other';
          String resolvedCustomType = '';

          if (isCustomType) {
            resolvedType = 'Other';
            resolvedCustomType = savedType;
          } else if (_addressTypeOptions.contains(savedType)) {
            resolvedType = savedType;
          } else {
            resolvedType = 'Other';
            resolvedCustomType = savedType;
          }

          final cAt = map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : DateTime.now();
          final uAt = map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : DateTime.now();

          _addresses.add(_AddressItem(
            id: map['id']?.toString() ?? _generateSecureId(),
            erpAddressCode: map['erpAddressCode']?.toString() ?? 'ADDR-${index.toString().padLeft(3, '0')}',
            version: map['version'] is int ? map['version'] : 1,
            createdAt: cAt,
            updatedAt: uAt,
            createdByUid: (map['createdByUid'] ?? '').toString(),
            updatedByUid: (map['updatedByUid'] ?? '').toString(),
            type: resolvedType,
            customType: resolvedCustomType,
            street: (map['street'] ?? '').toString(),
            city: (map['city'] ?? '').toString(),
            state: (map['state'] ?? '').toString(),
            pincode: (map['pincode'] ?? '').toString(),
            country: (map['country'] ?? 'India').toString(),
            gst: (map['gst'] ?? '').toString(),
            contactPerson: (map['contactPerson'] ?? '').toString(),
            contactPhone: (map['contactPhone'] ?? '').toString(),
            contactEmail: (map['contactEmail'] ?? '').toString(),
            tags: List<String>.from(map['tags'] ?? []),
            isActive: _parseBool(map['isActive'], fallback: true),
            isPrimary: _parseBool(map['isPrimary']),
            isBillingAddress: _parseBool(map['isBillingAddress']),
            isShippingAddress: _parseBool(map['isShippingAddress']),
            isDispatchAddress: _parseBool(map['isDispatchAddress']),
            isServiceAddress: _parseBool(map['isServiceAddress']),
            isExpanded: false,
            isExisting: true,
          ));
        }
      } else {
        _addresses.add(_AddressItem(
          erpAddressCode: 'ADDR-001',
          version: 1,
          type: 'Head Office',
          street: (data['street'] ?? '').toString(),
          city: (data['city'] ?? '').toString(),
          state: (data['state'] ?? '').toString(),
          pincode: (data['pincode'] ?? '').toString(),
          country: (data['country'] ?? 'India').toString(),
          isPrimary: true,
          isBillingAddress: true,
          isExpanded: false,
          isExisting: true,
        ));
      }

      if (_addresses.isNotEmpty && !_addresses.any((a) => a.isPrimary)) {
        _addresses.first.isPrimary = true;
      }
      _notifyAddressChange();

      final savedCustomerType = (data['customerType'] ?? '').toString().trim();
      if (savedCustomerType.isEmpty) {
        _customerType = null;
        _customerTypeCustomController.clear();
      } else if (_customerTypeOptions.contains(savedCustomerType)) {
        _customerType = savedCustomerType;
        _customerTypeCustomController.clear();
      } else {
        _customerType = 'Other';
        _customerTypeCustomController.text = savedCustomerType;
      }

      final savedIndustry = (data['industry'] ?? '').toString().trim();
      if (savedIndustry.isEmpty) {
        _industry = null;
        _industryCustomController.clear();
      } else if (_industryOptions.contains(savedIndustry)) {
        _industry = savedIndustry;
        _industryCustomController.clear();
      } else {
        _industry = 'Other';
        _industryCustomController.text = savedIndustry;
      }

      final sourceValue = (data['leadSource'] ?? '').toString().trim();
      if (sourceValue.isNotEmpty && _leadSourceOptions.contains(sourceValue)) {
        _leadSource = sourceValue;
      }

      final statusValue = (data['status'] ?? '').toString().trim();
      if (statusValue.isNotEmpty && _statusOptions.contains(statusValue)) {
        _status = statusValue;
      }

      final priorityValue = (data['priority'] ?? '').toString().trim();
      if (priorityValue.isNotEmpty && _priorityOptions.contains(priorityValue)) {
        _priority = priorityValue;
      }

      final stageValue = (data['customerStage'] ?? 'Potential Customer').toString().trim();
      if (_customerStageOptions.contains(stageValue)) {
        _customerStage = stageValue;
      } else {
        _customerStage = 'Potential Customer';
      }

      _notesController.text = (data['notes'] ?? data['remarks'] ?? '').toString();

      final assigned = (data['assignedToUid'] ?? '').toString().trim();
      if (assigned.isNotEmpty) {
        _assignedToUid = assigned;
      }

      _existingCreatedByUid = (data['createdByUid'] ?? data['createdBy'] ?? '').toString();
      _existingCreatedAt = data['createdAt'] as Timestamp?;

      _initialCustomerState = _captureCustomerCoreState();
      _safeSetState(() {});
    } catch (e, stack) {
      _logError(module: 'CRM', method: '_loadExistingCustomer', error: e, stack: stack, uid: widget.currentUserUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load customer: $e'), backgroundColor: Colors.red),
      );
    } finally {
      _safeSetState(() => _isLoadingExisting = false);
    }
  }

  Future<String> _getUserNameByUid(String uid) async {
    if (uid.trim().isEmpty) return '';
    if (_cachedUserNames.containsKey(uid)) return _cachedUserNames[uid]!;
    try {
      final doc = await _companyUsersCol.doc(uid).get();
      final data = doc.data() ?? {};
      final name = _extractUserName(data, fallbackUid: uid);
      _cachedUserNames[uid] = name;
      return name;
    } catch (_) {
      return uid;
    }
  }

  // --- ADDRESS MANAGEMENT ACTIONS ---
  String _getNextAddressCode() {
    int maxCode = 0;
    for (var a in _addresses) {
      if (a.erpAddressCode.startsWith('ADDR-')) {
        final numPart = a.erpAddressCode.substring(5);
        final val = int.tryParse(numPart) ?? 0;
        if (val > maxCode) maxCode = val;
      }
    }
    return 'ADDR-${(maxCode + 1).toString().padLeft(3, '0')}';
  }

  void _addAddress() {
    for(var a in _addresses) { a.isExpanded = false; }
    _addresses.add(_AddressItem(
      isPrimary: _addresses.isEmpty,
      isBillingAddress: _addresses.isEmpty,
      isExpanded: true,
      createdByUid: widget.currentUserUid,
      updatedByUid: widget.currentUserUid,
      erpAddressCode: _getNextAddressCode(),
    ));
    _notifyAddressChange();
  }

  void _duplicateAddress(int index) {
    final src = _addresses[index];
    for(var a in _addresses) { a.isExpanded = false; }
    _addresses.insert(
      index + 1,
      _AddressItem(
        erpAddressCode: _getNextAddressCode(),
        version: 1,
        type: src.type,
        customType: src.customTypeController.text,
        street: src.streetController.text,
        city: src.cityController.text,
        state: src.stateController.text,
        pincode: src.pincodeController.text,
        country: src.countryController.text,
        gst: src.gstController.text,
        contactPerson: src.contactPersonController.text,
        contactPhone: src.contactPhoneController.text,
        contactEmail: src.contactEmailController.text,
        tags: List.from(src.tags),
        isPrimary: false,
        isActive: true,
        isBillingAddress: false,
        isShippingAddress: false,
        isDispatchAddress: false,
        isServiceAddress: false,
        isExpanded: true,
        createdByUid: widget.currentUserUid,
        updatedByUid: widget.currentUserUid,
      ),
    );
    _notifyAddressChange();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address duplicated.'), duration: Duration(seconds: 2)),
    );
  }

  void _removeAddress(int index) {
    if (_addresses.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one address is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final removed = _addresses[index];
    _addresses.removeAt(index);
    removed.dispose();
    if (removed.isPrimary && _addresses.isNotEmpty) {
      _addresses.first.isPrimary = true;
    }
    _notifyAddressChange();
  }

  void _setPrimaryAddress(int index) {
    for (int i = 0; i < _addresses.length; i++) {
      _addresses[i].isPrimary = i == index;
    }
    _notifyAddressChange();
  }

  void _onReorderAddresses(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _addresses.removeAt(oldIndex);
    _addresses.insert(newIndex, item);
    _notifyAddressChange();
  }

  // --- 🚀 ENTERPRISE SEARCH KEYWORDS GENERATOR (N-GRAMS) ---
  List<String> _generateEnterpriseSearchKeywords(Map<String, dynamic> data, List<Map<String, dynamic>> addresses) {
    final Set<String> keywords = {};

    void addNgrams(String? text) {
      if (text == null || text.trim().isEmpty) return;

      final cleanText = text.toLowerCase().trim();
      keywords.add(cleanText);

      final parts = cleanText.split(RegExp(r'[\s\-_.\@]+'));

      for (final part in parts) {
        if (part.isEmpty) continue;

        // Never skip long words entirely. Cap prefixes at 30 to save index space, but allow full word match.
        String current = '';
        int limit = part.length > 30 ? 30 : part.length;

        for (int i = 0; i < limit; i++) {
          current += part[i];
          if (current.length >= 2) {
            keywords.add(current);
          }
        }
        if (part.length > 30) {
          keywords.add(part);
        }
      }
    }

    final normalizedName = normalizeCustomerName(data['companyName']);
    if (normalizedName.isNotEmpty) {
      addNgrams(normalizedName);
      keywords.add(normalizedName);
    }

    addNgrams(data['companyName']);
    addNgrams(data['customerCode']);
    addNgrams(data['phone']);
    addNgrams(data['phoneDigitsOnly']);
    addNgrams(data['alternatePhone']);
    addNgrams(data['businessEmail']);
    addNgrams(data['gst']);
    addNgrams(data['pan']);
    addNgrams(data['contactName']);

    for (final a in addresses) {
      addNgrams(a['city']);
      addNgrams(a['state']);
      addNgrams(a['gst']);
      addNgrams(a['contactPerson']);
      addNgrams(a['contactPhone']);
      addNgrams(a['contactEmail']);

      final tagsList = a['tags'];
      if (tagsList is List) {
        for (var tag in tagsList) {
          addNgrams(tag.toString());
        }
      }
    }

    final list = keywords.toList();
    if (list.length > 1000) {
      return list.sublist(0, 1000);
    }
    return list;
  }

  String _buildExportAddress(Map<String, dynamic> addr) {
    final parts = [addr['street'], addr['city'], addr['state'], addr['pincode'], addr['country']]
        .where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
    String res = parts;
    if (addr['gst']?.toString().isNotEmpty == true) res += '\nGST: ${addr['gst']}';
    if (addr['contactPerson']?.toString().isNotEmpty == true) {
      res += '\nContact: ${addr['contactPerson']}';
      if (addr['contactPhone']?.toString().isNotEmpty == true) res += ' (${addr['contactPhone']})';
    }
    return res;
  }

  String _buildSearchIndex(Map<String, dynamic> addr) {
    return [
      addr['type'], addr['customType'], addr['street'], addr['city'],
      addr['state'], addr['pincode'], addr['country'], addr['gst'],
      addr['contactPerson'], addr['contactPhone'], addr['contactEmail']
    ].where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(' ').toLowerCase();
  }

  // --- SECURE CUSTOMER CODE GENERATOR ---
  Future<String> _generateSecureCustomerCode() async {
    final counterRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('metadata')
        .doc('customer_counter');

    int retries = 3;
    int delayMs = 500;

    while (retries > 0) {
      try {
        return await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(counterRef);
          int currentCount = 0;
          if (snapshot.exists) {
            currentCount = snapshot.data()?['count'] ?? 0;
          }
          int nextCount = currentCount + 1;
          transaction.set(counterRef, {'count': nextCount}, SetOptions(merge: true));
          return 'CUST-${nextCount.toString().padLeft(4, '0')}';
        }, timeout: const Duration(seconds: 15));
      } catch (e) {
        retries--;
        if (retries == 0) break;
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2;
      }
    }

    final fallbackSnap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('customers')
        .get();

    int maxNumber = 0;
    final codeRegex = RegExp(r'^CUST[-\s]?(\d+)$', caseSensitive: false);

    for (final doc in fallbackSnap.docs) {
      final code = (doc.data()['customerCode'] ?? '').toString().trim();
      final match = codeRegex.firstMatch(code);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '') ?? 0;
        if (number > maxNumber) maxNumber = number;
      }
    }

    final fallbackNext = maxNumber + 1;

    await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('metadata')
        .doc('customer_counter')
        .set({'count': fallbackNext}, SetOptions(merge: true));

    return 'CUST-${fallbackNext.toString().padLeft(4, '0')}';
  }

  Future<String?> _checkCustomerDuplicate({
    String? name,
    String? gst,
    String? phone,
    String? email,
  }) async {
    final customerDocs = await _customersCol.get();
    final customerList = customerDocs.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    return findDuplicateMatch(
      customers: customerList,
      currentCustomerId: widget.existingDoc?.id,
      name: name,
      gst: gst,
      phone: phone,
      email: email,
    );
  }

  // --- DUPLICATE CHECK WARNINGS ---
  void _checkWarnings() {
    final Set<String> gsts = {};
    final Set<String> emails = {};
    final Set<String> phones = {};
    bool hasWarnings = false;

    if (_gstController.text.isNotEmpty) gsts.add(_gstController.text.trim().toLowerCase());
    if (_businessEmailController.text.isNotEmpty) emails.add(_businessEmailController.text.trim().toLowerCase());
    if (_phoneController.text.isNotEmpty) phones.add(_phoneController.text.trim().toLowerCase());

    for (var a in _addresses) {
      final g = a.gstController.text.trim().toLowerCase();
      final e = a.contactEmailController.text.trim().toLowerCase();
      final p = a.contactPhoneController.text.trim().toLowerCase();

      if (g.isNotEmpty && !gsts.add(g)) hasWarnings = true;
      if (e.isNotEmpty && !emails.add(e)) hasWarnings = true;
      if (p.isNotEmpty && !phones.add(p)) hasWarnings = true;
    }

    if (hasWarnings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warning: Duplicate GST, Phone, or Email detected internally.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // --- DATA INTEGRITY VALIDATORS ---
  bool _runPreSaveValidations() {
    final mainGst = _gstController.text.trim().toUpperCase();
    if (mainGst.isNotEmpty && !_isValidGst(mainGst)) {
      _scrollToTop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primary GST is invalid. Check format and state code.'), backgroundColor: Colors.red),
      );
      return false;
    }

    final mainPan = _panController.text.trim().toUpperCase();
    if (mainPan.isNotEmpty && !_isValidPan(mainPan)) {
      _scrollToTop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PAN is invalid. Expected format: 5 letters, 4 numbers, 1 letter.'), backgroundColor: Colors.red),
      );
      return false;
    }

    for (var a in _addresses) {
      final aGst = a.gstController.text.trim().toUpperCase();
      if (aGst.isNotEmpty && !_isValidGst(aGst)) {
        a.isExpanded = true;
        _safeSetState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Address "${a.erpAddressCode}" has an invalid GST.'), backgroundColor: Colors.red),
        );
        return false;
      }
    }

    final primaryCount = _addresses.where((a) => a.isPrimary).length;
    if (primaryCount != 1) {
      for (var a in _addresses) { a.isPrimary = false; }
      _addresses.first.isPrimary = true;
    }

    final Set<String> codes = {};
    for (var a in _addresses) {
      if (!codes.add(a.erpAddressCode)) {
        a.erpAddressCode = _getNextAddressCode();
        codes.add(a.erpAddressCode);
      }
    }

    return true;
  }

  // --- CORE SAVE LOGIC ---
  Future<void> _saveCustomer() async {
    if (_isSaving) return;

    final currentSession = DateTime.now().millisecondsSinceEpoch.toString();
    _saveSessionId = currentSession;

    if (!_formKey.currentState!.validate()) {
      _scrollToTop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_addresses.isEmpty) {
      _scrollToTop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one address is required'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_runPreSaveValidations()) {
      return;
    }

    FocusScope.of(context).unfocus();
    _checkWarnings();

    final assignedTo = _canAssignOthers ? (_assignedToUid ?? '').trim() : widget.currentUserUid;

    if (assignedTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select assigned user'), backgroundColor: Colors.red),
      );
      return;
    }

    _safeSetState(() => _isSaving = true);

    try {
      final Set<String> allModifiedSections = {};
      final currentCoreState = _captureCustomerCoreState();

      if (_isEdit) {
        currentCoreState.forEach((k, v) {
          if (_initialCustomerState[k] != v) allModifiedSections.add('classification');
        });
      }

      final List<Map<String, dynamic>> addressesPayload = _addresses.map((addr) {
        final street = addr.streetController.text.trim();
        final city = addr.cityController.text.trim();
        final state = addr.stateController.text.trim();
        final pincode = addr.pincodeController.text.trim();
        final country = addr.countryController.text.trim();

        final addressParts = <String>[street, city, state, pincode, country].where((e) => e.isNotEmpty).toList();
        final combinedAddress = addressParts.join(', ');

        final isCustom = addr.type == 'Other';
        final finalType = isCustom ? addr.customTypeController.text.trim() : addr.type;

        final modifiedFields = addr.getModifiedFields();
        if (modifiedFields.isNotEmpty) {
          allModifiedSections.add('addresses');
        }

        final payloadMap = <String, dynamic>{
          'id': addr.id,
          'erpAddressCode': addr.erpAddressCode,
          'version': _isEdit ? (addr.version + (modifiedFields.isNotEmpty ? 1 : 0)) : 1,
          'versionHistoryEnabled': true,
          'type': finalType,
          'isCustomType': isCustom,
          'street': street,
          'city': city,
          'state': state,
          'pincode': pincode,
          'country': country,
          'gst': addr.gstController.text.trim().toUpperCase(),
          'contactPerson': addr.contactPersonController.text.trim(),
          'contactPhone': addr.contactPhoneController.text.trim(),
          'contactPhoneNormalized': normalizePhone(addr.contactPhoneController.text),
          'contactEmail': normalizeEmail(addr.contactEmailController.text),
          'tags': addr.tags,
          'isPrimary': addr.isPrimary,
          'isActive': addr.isActive,
          'isBillingAddress': addr.isBillingAddress,
          'isShippingAddress': addr.isShippingAddress,
          'isDispatchAddress': addr.isDispatchAddress,
          'isServiceAddress': addr.isServiceAddress,
          'combinedAddress': combinedAddress,
          'searchableAddress': combinedAddress.toLowerCase(),
          'createdAt': Timestamp.fromDate(addr.createdAt),
          'updatedAt': modifiedFields.isNotEmpty ? Timestamp.fromDate(DateTime.now()) : Timestamp.fromDate(addr.updatedAt),
          'createdByUid': addr.createdByUid.isEmpty ? widget.currentUserUid : addr.createdByUid,
          'updatedByUid': modifiedFields.isNotEmpty ? widget.currentUserUid : addr.updatedByUid,
          'lastModifiedFields': modifiedFields,
          'latitude': null,
          'longitude': null,
          'geoUpdatedAt': null,
        };

        payloadMap['fullExportAddress'] = _buildExportAddress(payloadMap);
        payloadMap['searchIndex'] = _buildSearchIndex(payloadMap);

        return payloadMap;
      }).toList();

      final primaryAddr = addressesPayload.firstWhere((a) => a['isPrimary'] == true, orElse: () => addressesPayload.first);

      final customType = _customerTypeCustomController.text.trim();
      final customIndustry = _industryCustomController.text.trim();

      final finalCustomerType = _customerType == 'Other' ? (customType.isNotEmpty ? customType : 'Other') : (_customerType ?? '').trim();
      final finalIndustry = _industry == 'Other' ? (customIndustry.isNotEmpty ? customIndustry : 'Other') : (_industry ?? '').trim();

      final name = _companyController.text.trim();
      final gst = normalizeGST(_gstController.text);
      final phone = normalizePhone(_phoneController.text);
      final email = normalizeEmail(_businessEmailController.text);

      final duplicateField = await _checkCustomerDuplicate(
        name: name,
        gst: gst,
        phone: phone,
        email: email,
      );
      if (_saveSessionId != currentSession) return;

      if (duplicateField != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(duplicateValidationMessage(duplicateField)), backgroundColor: Colors.red),
        );
        _safeSetState(() => _isSaving = false);
        return;
      }

      final assignedToName = await _getUserNameByUid(assignedTo);
      final currentUserName = _currentUserName.isNotEmpty ? _currentUserName : await _getUserNameByUid(widget.currentUserUid);

      if (_saveSessionId != currentSession) return;

      final String finalCustomerCode = _isEdit ? (_customerCode ?? '') : await _generateSecureCustomerCode();

      final Map<String, dynamic> rawUpdateData = {
        'companyId': widget.companyId,
        'customerCode': finalCustomerCode,

        'name': name,
        'companyName': name,
        'companyNameLower': normalizeCustomerName(name),
        'companyNameNormalized': normalizeCustomerName(name),
        'customerNameNormalized': normalizeCustomerName(name),
        'phone': _phoneController.text.trim(),
        'phoneNormalized': normalizePhone(_phoneController.text),
        'phoneNumberNormalized': normalizePhone(_phoneController.text),
        'phoneLast10': normalizeCustomerPhoneLast10(_phoneController.text),
        'phoneDigitsOnly': _phoneController.text.replaceAll(RegExp(r'\D'), ''),
        'companyPhone': _phoneController.text.trim(),
        'alternatePhone': _altPhoneController.text.trim(),
        'alternatePhoneNormalized': normalizePhone(_altPhoneController.text),
        'email': _businessEmailController.text.trim(),
        'emailNormalized': normalizeEmail(_businessEmailController.text),
        'emailLower': normalizeEmail(_businessEmailController.text),
        'businessEmail': _businessEmailController.text.trim(),
        'gst': gst,
        'gstNumberNormalized': normalizeGST(_gstController.text),
        'gstNormalized': normalizeGST(_gstController.text),
        'pan': _panController.text.trim().toUpperCase(),
        'website': _websiteController.text.trim(),

        'customerType': finalCustomerType,
        'industry': finalIndustry,
        'leadSource': (_leadSource ?? '').trim(),
        'status': (_status ?? 'Active').trim(),
        'priority': (_priority ?? 'Medium').trim(),
        'customerStage': (_customerStage ?? 'Potential Customer').trim(),

        'addresses': addressesPayload,

        'cityLower': (primaryAddr['city'] ?? '').toString().toLowerCase(),
        'stateLower': (primaryAddr['state'] ?? '').toString().toLowerCase(),
        'countryLower': (primaryAddr['country'] ?? '').toString().toLowerCase(),

        'address': primaryAddr['combinedAddress'],
        'street': primaryAddr['street'],
        'city': primaryAddr['city'],
        'state': primaryAddr['state'],
        'pincode': primaryAddr['pincode'],
        'country': primaryAddr['country'],

        'contactName': _contactNameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),

        'notes': _notesController.text.trim(),
        'remarks': _notesController.text.trim(),

        'assignedToUid': assignedTo,
        'assignedToName': assignedToName,
        'assignedByUid': widget.currentUserUid,
        'assignedByName': currentUserName,

        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.currentUserUid,
        'updatedByUid': widget.currentUserUid,
        'updatedByName': currentUserName,

        'lastModifiedSection': allModifiedSections.isEmpty ? 'none' : allModifiedSections.join(','),
        'auditSummary': {
          'lastAction': _isEdit ? 'updated' : 'created',
          'addressCount': addressesPayload.length,
          'modifiedSections': allModifiedSections.toList(),
        }
      };

      rawUpdateData['searchKeywords'] = _generateEnterpriseSearchKeywords(rawUpdateData, addressesPayload);

      final nowUpdateData = _sanitizePayload(rawUpdateData);

      if (_estimatePayloadSize(nowUpdateData) > 950000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data size too large. Please reduce address count or notes.'), backgroundColor: Colors.red),
        );
        _safeSetState(() => _isSaving = false);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      final DocumentReference customerRef = widget.existingDoc ?? _customersCol.doc();

      if (widget.existingDoc == null) {
        nowUpdateData.addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.currentUserUid,
          'createdByUid': widget.currentUserUid,
          'createdByName': currentUserName,
          'recordOwnerUid': widget.currentUserUid,
          'recordOwnerName': currentUserName,
          'isActive': true,
          'contactsCount': 0,

          'isDeleted': false,
          'deletedAt': null,
          'deletedByUid': '',
          'isLocked': false,
          'lockedAt': null,
          'lockedByUid': '',

          'visibleToRoles': <String>[],
          'editableByRoles': <String>[],

          'quotationCount': 0,
          'inquiryCount': 0,
          'salesOrderCount': 0,
          'invoiceCount': 0,
          'totalBusinessValue': 0.0,
          'lastActivityAt': FieldValue.serverTimestamp(),

          'followUpCount': 0,
          'lastFollowUpAt': null,
          'lastFollowUpByUid': '',
          'lastFollowUpByName': '',
          'lastFollowUpMode': '',
          'lastFollowUpSummary': '',
          'lastFollowUpOutcome': '',
          'nextFollowUpDate': null,
        });

        batch.set(customerRef, nowUpdateData);

        final contactName = _contactNameController.text.trim();
        final contactPhone = _phoneController.text.trim();
        final contactEmail = _businessEmailController.text.trim();

        final hasContactData = contactName.isNotEmpty || _designationController.text.trim().isNotEmpty || _departmentController.text.trim().isNotEmpty || contactPhone.isNotEmpty || contactEmail.isNotEmpty;

        if (hasContactData) {
          final contactRef = customerRef.collection('contacts').doc();
          batch.set(contactRef, _sanitizePayload({
            'companyId': widget.companyId,
            'customerId': customerRef.id,
            'name': contactName,
            'designation': _designationController.text.trim(),
            'department': _departmentController.text.trim(),
            'phone': contactPhone,
            'phoneNormalized': normalizePhone(contactPhone),
            'email': normalizeEmail(contactEmail),
            'emailNormalized': normalizeEmail(contactEmail),
            'isPrimary': true,
            'isActive': true,
            'startDate': FieldValue.serverTimestamp(),
            'endDate': null,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': widget.currentUserUid,
            'createdByUid': widget.currentUserUid,
            'createdByName': currentUserName,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': widget.currentUserUid,
            'updatedByName': currentUserName,
          }));
          batch.update(customerRef, {'contactsCount': 1});
        }
      } else {
        nowUpdateData['createdBy'] = _existingCreatedByUid;
        nowUpdateData['createdByUid'] = _existingCreatedByUid;
        nowUpdateData['createdAt'] = _existingCreatedAt;
        batch.update(customerRef, nowUpdateData);
      }

      await batch.commit();

      if (_saveSessionId != currentSession) return;

      await _clearDraftLocally();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingDoc == null ? 'Customer created successfully' : 'Customer updated successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e, stack) {
      _logError(module: 'CRM', method: '_saveCustomer', error: e, stack: stack, uid: widget.currentUserUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save customer. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (_saveSessionId == currentSession) {
        _safeSetState(() => _isSaving = false);
      }
    }
  }

  // --- UI BUILDERS ---

  Widget _buildAssignUserDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activeUsersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 2));
        }

        if (snap.hasError) {
          return Text('Failed to load users: ${snap.error}', style: const TextStyle(color: Colors.red));
        }

        final docs = snap.data?.docs.toList() ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        docs.sort((a, b) {
          final an = _extractUserName(a.data(), fallbackUid: a.id).toLowerCase();
          final bn = _extractUserName(b.data(), fallbackUid: b.id).toLowerCase();
          return an.compareTo(bn);
        });

        for (final d in docs) {
          _cachedUserNames[d.id] = _extractUserName(d.data(), fallbackUid: d.id);
        }

        if (docs.isEmpty) {
          return const Text('No active users found');
        }

        String? safeAssignedValue;
        final hasAssignedUser = docs.any((doc) => doc.id == _assignedToUid);

        if (hasAssignedUser) {
          safeAssignedValue = _assignedToUid;
        } else if (_canAssignOthers) {
          safeAssignedValue = null;
        } else {
          final currentUserExists = docs.any((doc) => doc.id == widget.currentUserUid);
          safeAssignedValue = currentUserExists ? widget.currentUserUid : null;
        }

        return StatefulBuilder(
          builder: (context, setLocalState) => DropdownButtonFormField<String>(
            value: safeAssignedValue,
            decoration: _inputDecoration(label: 'Assign to', icon: Icons.person_pin_circle_outlined),
            items: docs.map((doc) {
              final data = doc.data();
              final name = _extractUserName(data, fallbackUid: doc.id);
              final role = (data['role'] ?? '').toString().trim();
              return DropdownMenuItem<String>(
                value: doc.id,
                child: Text(role.isEmpty ? name : '$name • $role', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _canAssignOthers ? (value) {
              _assignedToUid = value;
              setLocalState(() {});
            } : null,
            validator: (value) {
              final finalValue = _canAssignOthers ? value : widget.currentUserUid;
              if (finalValue == null || finalValue.trim().isEmpty) return 'Please select assigned user';
              return null;
            },
          ),
        );
      },
    );
  }

  Widget _buildAssignmentSection() {
    return _SectionBlock(
      title: 'Ownership & Assignment',
      subtitle: 'Who owns and manages this customer record',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssignUserDropdown(),
          if (!_canAssignOthers) ...[
            const SizedBox(height: 10),
            Text('You can create customer only for yourself.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          titleSpacing: 16,
          title: Text(_isEdit ? 'Edit Customer' : 'Add Customer', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          actions: [
            if (_customerCode != null || !_isEdit)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      _isEdit ? 'Code: $_customerCode' : 'Code: Auto-generated',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade800),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _isLoadingExisting
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 980;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: Column(
                                    children: [
                                      _buildAccountSection(),
                                      const SizedBox(height: 16),
                                      _buildAddressesSection(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      _buildPrimaryContactSection(),
                                      const SizedBox(height: 16),
                                      _buildClassificationSection(),
                                      const SizedBox(height: 16),
                                      _buildAssignmentSection(),
                                      const SizedBox(height: 16),
                                      _buildNotesSection(),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              _buildAccountSection(),
                              const SizedBox(height: 16),
                              _buildPrimaryContactSection(),
                              const SizedBox(height: 16),
                              _buildClassificationSection(),
                              const SizedBox(height: 16),
                              _buildAssignmentSection(),
                              const SizedBox(height: 16),
                              _buildAddressesSection(),
                              const SizedBox(height: 16),
                              _buildNotesSection(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottomSaveBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return _SectionBlock(
      title: 'Account Details',
      subtitle: 'Business identity and core contact channels',
      child: Column(
        children: [
          _ResponsiveRow(
            children: [
              CustomerDuplicateLookupField(
                lookupType: CustomerDuplicateLookupType.name,
                searchService: _liveDuplicateSearchService,
                excludedCustomerId: widget.existingDoc?.id,
                onViewCustomer: _openDuplicateCustomer,
                fieldBuilder: (onChanged) => _buildTextField(
                  controller: _companyController,
                  label: 'Company / Firm Name *',
                  icon: Icons.apartment_outlined,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  onChanged: onChanged,
                ),
              ),
              _buildTextField(
                controller: _websiteController,
                label: 'Website',
                icon: Icons.language_outlined,
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResponsiveRow(
            children: [
              CustomerDuplicateLookupField(
                lookupType: CustomerDuplicateLookupType.phone,
                searchService: _liveDuplicateSearchService,
                excludedCustomerId: widget.existingDoc?.id,
                onViewCustomer: _openDuplicateCustomer,
                fieldBuilder: (onChanged) => _buildTextField(
                  controller: _phoneController,
                  label: 'Primary Phone *',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  onChanged: onChanged,
                ),
              ),
              _buildTextField(
                controller: _altPhoneController,
                label: 'Alternate Phone',
                icon: Icons.local_phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResponsiveRow(
            children: [
              CustomerDuplicateLookupField(
                lookupType: CustomerDuplicateLookupType.email,
                searchService: _liveDuplicateSearchService,
                excludedCustomerId: widget.existingDoc?.id,
                onViewCustomer: _openDuplicateCustomer,
                fieldBuilder: (onChanged) => _buildTextField(
                  controller: _businessEmailController,
                  label: 'Business Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: onChanged,
                  validator: (v) {
                    final email = (v ?? '').trim();
                    if (email.isEmpty) return null;
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter valid email';
                    return null;
                  },
                ),
              ),
              CustomerDuplicateLookupField(
                lookupType: CustomerDuplicateLookupType.gst,
                searchService: _liveDuplicateSearchService,
                excludedCustomerId: widget.existingDoc?.id,
                onViewCustomer: _openDuplicateCustomer,
                fieldBuilder: (onChanged) => _buildTextField(
                  controller: _gstController,
                  label: 'Primary GST',
                  icon: Icons.receipt_long_outlined,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResponsiveRow(
            children: [
              _buildTextField(
                controller: _panController,
                label: 'PAN',
                icon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationSection() {
    return StatefulBuilder(
        builder: (context, setLocalState) {
          return _SectionBlock(
            title: 'CRM Classification',
            subtitle: 'Standard segmentation and lifecycle fields',
            child: Column(
              children: [
                _ResponsiveRow(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _customerStage,
                      decoration: _inputDecoration(label: 'Customer Stage', icon: Icons.account_tree_outlined),
                      items: _customerStageOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (value) => setLocalState(() => _customerStage = value),
                    ),
                    DropdownButtonFormField<String>(
                      value: _customerType,
                      decoration: _inputDecoration(label: 'Customer Type', icon: Icons.groups_2_outlined),
                      items: _customerTypeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (value) {
                        setLocalState(() {
                          _customerType = value;
                          if (value != 'Other') _customerTypeCustomController.clear();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ResponsiveRow(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _industry,
                      decoration: _inputDecoration(label: 'Industry', icon: Icons.factory_outlined),
                      items: _industryOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (value) {
                        setLocalState(() {
                          _industry = value;
                          if (value != 'Other') _industryCustomController.clear();
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: _leadSource,
                      decoration: _inputDecoration(label: 'Lead Source', icon: Icons.campaign_outlined),
                      items: _leadSourceOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (value) => setLocalState(() => _leadSource = value),
                    ),
                  ],
                ),
                if (_customerType == 'Other' || _industry == 'Other') ...[
                  const SizedBox(height: 12),
                  _ResponsiveRow(
                    children: [
                      _customerType == 'Other'
                          ? _buildTextField(controller: _customerTypeCustomController, label: 'Custom Customer Type', icon: Icons.edit_outlined)
                          : const SizedBox.shrink(),
                      _industry == 'Other'
                          ? _buildTextField(controller: _industryCustomController, label: 'Custom Industry', icon: Icons.tune_outlined)
                          : const SizedBox.shrink(),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _ResponsiveRow(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: _inputDecoration(label: 'Status', icon: Icons.verified_user_outlined),
                      items: _statusOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (value) => setLocalState(() => _status = value),
                    ),
                    DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: _inputDecoration(label: 'Priority', icon: Icons.flag_outlined),
                      items: _priorityOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (value) => setLocalState(() => _priority = value),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
    );
  }

  Widget _buildPrimaryContactSection() {
    return _SectionBlock(
      title: 'Primary Contact',
      subtitle: 'Main person linked with this account',
      child: Column(
        children: [
          _buildTextField(
            controller: _contactNameController,
            label: 'Contact Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _ResponsiveRow(
            children: [
              _buildTextField(controller: _designationController, label: 'Designation', icon: Icons.badge_outlined),
              _buildTextField(controller: _departmentController, label: 'Department', icon: Icons.account_tree_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAddressState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No Addresses Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          const SizedBox(height: 6),
          Text('Add at least one address to continue.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addAddress,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Address'),
            style: ElevatedButton.styleFrom(elevation: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressesSection() {
    return _SectionBlock(
      title: 'Business Addresses',
      subtitle: 'Locations, shipping points, and regional contact details',
      child: ValueListenableBuilder<int>(
          valueListenable: _addressListNotifier,
          builder: (context, _, __) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_addresses.isEmpty)
                  _buildEmptyAddressState()
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _addresses.length,
                    buildDefaultDragHandles: false,
                    onReorderStart: (_) => FocusScope.of(context).unfocus(),
                    onReorder: _onReorderAddresses,
                    proxyDecorator: (child, index, animation) => Material(color: Colors.transparent, child: child),
                    itemBuilder: (context, index) {
                      final address = _addresses[index];
                      return _AddressCardWidget(
                        key: ValueKey(address.id),
                        index: index,
                        address: address,
                        isDuplicateType: address.type != 'Other' && _addresses.where((a) => a.type == address.type).length > 1,
                        onDuplicate: () => _duplicateAddress(index),
                        onRemove: () => _removeAddress(index),
                        onSetPrimary: () => _setPrimaryAddress(index),
                      );
                    },
                  ),

                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addAddress,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Add Another Address'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          }
      ),
    );
  }

  Widget _buildNotesSection() {
    return _SectionBlock(
      title: 'Internal Notes',
      subtitle: 'Sales context, remarks or follow-up notes',
      child: _buildTextField(
        controller: _notesController,
        label: 'Notes / Remarks',
        icon: Icons.edit_note_outlined,
        maxLines: 5,
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
                    _isEdit ? 'Update the customer record after reviewing the details.' : 'Save this new customer record to CRM.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 170,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveCustomer,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : Icon(_isEdit ? Icons.save_outlined : Icons.add_circle_outline, size: 18),
                    label: Text(_isEdit ? 'Update' : 'Save Customer'),
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
}

const List<String> _addressTypeOptions = [
  'Head Office', 'Corporate Office', 'Factory', 'Branch Office', 'Warehouse', 'Site Address', 'Billing Address', 'Shipping Address', 'Other',
];

const List<String> _customerStageOptions = ['Potential Customer', 'Existing Customer'];

const List<String> _customerTypeOptions = [
  'End Customer', 'Distributor', 'Dealer', 'Channel Partner', 'OEM', 'System Integrator', 'Contractor', 'Fabricator', 'Manufacturer', 'Consultant', 'Government', 'Public Sector', 'Educational Institution', 'Service Provider', 'Retailer', 'Trader', 'Other',
];

const List<String> _industryOptions = [
  'Automotive', 'Aerospace & Defense', 'Construction', 'Engineering', 'Energy & Power', 'EPC', 'Fabrication', 'Food & Beverage', 'Healthcare & Medical', 'Infrastructure', 'Manufacturing', 'Marine & Shipbuilding', 'Metal & Steel', 'Mining', 'Oil & Gas', 'Pharmaceuticals', 'Railways', 'Renewable Energy', 'Textiles', 'Trading', 'Utilities', 'Warehousing & Logistics', 'Other',
];

const List<String> _leadSourceOptions = [
  'Direct', 'Reference', 'Website', 'WhatsApp', 'Email Campaign', 'Phone Call', 'Sales Visit', 'Exhibition', 'Distributor', 'Digital Marketing', 'Marketplace', 'Tender', 'Other',
];

const List<String> _statusOptions = ['Active', 'Prospect', 'Lead', 'Dormant', 'Blocked'];

const List<String> _priorityOptions = ['Low', 'Medium', 'High', 'Critical'];
