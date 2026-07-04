// FILE PATH: lib/modules/crm/contacts/screens_add_contact.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_contact/add_contact_widgets.dart';

part 'add_contact/add_contact_form_sections.dart';
part 'add_contact/add_contact_header_footer.dart';
part 'add_contact/add_contact_layout_sections.dart';

// --- HELPERS ---
bool _safeBool(dynamic val) {
  if (val == null) return false;
  if (val is bool) return val;
  if (val is int) return val == 1;
  final s = val.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

String _safeString(dynamic val) {
  return (val ?? '').toString().trim();
}

// --- SCREEN ---
class ScreensAddContact extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final DocumentSnapshot<Map<String, dynamic>>? contactDoc;

  const ScreensAddContact({
    super.key,
    required this.companyRef,
    this.contactDoc,
  });

  @override
  State<ScreensAddContact> createState() => _ScreensAddContactState();
}

class _ScreensAddContactState extends State<ScreensAddContact> {
  final _formKey = GlobalKey<FormState>();

  // Core Controllers
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();

  // Communication Controllers
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _officePhoneController = TextEditingController();
  final _extensionController = TextEditingController();
  final _emailController = TextEditingController();

  // Social & Notes Controllers
  final _linkedinController = TextEditingController();
  final _assistantNameController = TextEditingController();
  final _internalNotesController = TextEditingController();
  final _escalationNotesController = TextEditingController();

  // Enterprise Selectors
  bool _isPrimary = false;
  String _contactStatus = 'Active';
  String _contactType = 'Commercial';
  String _department = 'Management';
  String _decisionRole = 'User';
  String _authorityLevel = 'Manager / Head';
  String _preferredComm = 'Phone';

  // Multi-Location
  String? _linkedAddressId;
  String? _linkedAddressLabel;
  List<Map<String, dynamic>> _companyAddresses = [];

  bool _isSaving = false;
  bool _isLoadingCompany = true;
  String _companyName = '';
  String _companyLocation = '';

  CollectionReference<Map<String, dynamic>> get _contactsRef =>
      widget.companyRef.collection('contacts');

  bool get _isEdit => widget.contactDoc != null;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();

    final doc = widget.contactDoc;
    if (doc != null) {
      final data = doc.data() ?? {};

      // Core
      _nameController.text = _safeString(data['name']);
      _designationController.text = _safeString(data['designation']);
      _isPrimary = _safeBool(data['isPrimary']);

      bool isActive = data.containsKey('isActive') ? _safeBool(data['isActive']) : true;
      _contactStatus = _safeString(data['contactStatus']).isNotEmpty ? _safeString(data['contactStatus']) : (isActive ? 'Active' : 'Inactive');

      // Contact Numbers
      _phoneController.text = _safeString(data['phone']);
      _alternatePhoneController.text = _safeString(data['alternatePhone']);
      _officePhoneController.text = _safeString(data['officePhone']);
      _extensionController.text = _safeString(data['extension']);
      _emailController.text = _safeString(data['email']);

      // Selectors
      _contactType = _safeString(data['contactType']).isNotEmpty ? _safeString(data['contactType']) : 'Commercial';
      _department = _safeString(data['department']).isNotEmpty ? _safeString(data['department']) : 'Management';
      _decisionRole = _safeString(data['decisionRole']).isNotEmpty ? _safeString(data['decisionRole']) : 'User';
      _authorityLevel = _safeString(data['authorityLevel']).isNotEmpty ? _safeString(data['authorityLevel']) : 'Manager / Head';
      _preferredComm = _safeString(data['preferredCommunicationMode']).isNotEmpty ? _safeString(data['preferredCommunicationMode']) : 'Phone';

      // Location Link
      _linkedAddressId = _safeString(data['linkedAddressId']).isNotEmpty ? _safeString(data['linkedAddressId']) : null;
      _linkedAddressLabel = _safeString(data['linkedAddressLabel']).isNotEmpty ? _safeString(data['linkedAddressLabel']) : null;

      // Extras
      _linkedinController.text = _safeString(data['linkedin']);
      _assistantNameController.text = _safeString(data['assistantName']);
      _internalNotesController.text = _safeString(data['internalNotes']);
      _escalationNotesController.text = _safeString(data['escalationNotes']);
    }
  }

  Future<void> _loadCompanyInfo() async {
    try {
      final snapshot = await widget.companyRef.get();
      final data = snapshot.data() ?? {};

      final companyName = _safeString(data['companyName'].toString().isNotEmpty ? data['companyName'] : data['name']);
      final city = _safeString(data['city']);
      final state = _safeString(data['state']);

      String location = '';
      if (city.isNotEmpty && state.isNotEmpty) {
        location = '$city, $state';
      } else if (city.isNotEmpty) {
        location = city;
      } else if (state.isNotEmpty) {
        location = state;
      }

      if (data['addresses'] is List) {
        final List<dynamic> rawAddresses = data['addresses'];
        _companyAddresses = rawAddresses.whereType<Map<String, dynamic>>().toList();
      }

      if (_linkedAddressId != null && !_companyAddresses.any((a) => a['id'] == _linkedAddressId || a['label'] == _linkedAddressLabel)) {
        _linkedAddressId = null;
        _linkedAddressLabel = null;
      }

      if (!mounted) return;
      setState(() {
        _companyName = companyName;
        _companyLocation = location;
        _isLoadingCompany = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingCompany = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _officePhoneController.dispose();
    _extensionController.dispose();
    _emailController.dispose();
    _linkedinController.dispose();
    _assistantNameController.dispose();
    _internalNotesController.dispose();
    _escalationNotesController.dispose();
    super.dispose();
  }

  void _setPrimaryContact(bool? value) {
    setState(() => _isPrimary = value ?? false);
  }

  Future<void> _unsetOtherPrimaryContacts() async {
    final existingContacts = await _contactsRef.get();
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in existingContacts.docs) {
      if (widget.contactDoc != null && doc.id == widget.contactDoc!.id) continue;

      if (doc.data()['isPrimary'] == true) {
        batch.update(doc.reference, {
          'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isPrimary) await _unsetOtherPrimaryContacts();

      final baseData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _department,
        'contactType': _contactType,
        'decisionRole': _decisionRole,
        'authorityLevel': _authorityLevel,

        'isPrimary': _isPrimary,
        'contactStatus': _contactStatus,
        'isActive': _contactStatus == 'Active',

        'phone': _phoneController.text.trim(),
        'alternatePhone': _alternatePhoneController.text.trim(),
        'officePhone': _officePhoneController.text.trim(),
        'extension': _extensionController.text.trim(),
        'email': _emailController.text.trim(),
        'preferredCommunicationMode': _preferredComm,

        'linkedAddressId': _linkedAddressId ?? '',
        'linkedAddressLabel': _linkedAddressLabel ?? '',

        'linkedin': _linkedinController.text.trim(),
        'assistantName': _assistantNameController.text.trim(),
        'internalNotes': _internalNotesController.text.trim(),
        'escalationNotes': _escalationNotesController.text.trim(),
      };

      if (widget.contactDoc == null) {
        await _contactsRef.add({
          ...baseData,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.uid,
          'createdByUid': currentUser.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUser.uid,
          'updatedByUid': currentUser.uid,
        });
      } else {
        await widget.contactDoc!.reference.update({
          ...baseData,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUser.uid,
          'updatedByUid': currentUser.uid,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Contact updated successfully' : 'Contact created successfully'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save contact: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Enterprise CRM background
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Contact' : 'New Contact', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoadingCompany
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(child: _buildScrollableContent()),
            _buildBottomSaveBar(),
          ],
        ),
      ),
    );
  }
}