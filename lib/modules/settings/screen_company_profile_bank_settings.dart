import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScreenCompanyProfileBankSettings extends StatefulWidget {
  final String companyId;

  const ScreenCompanyProfileBankSettings({super.key, required this.companyId});

  @override
  State<ScreenCompanyProfileBankSettings> createState() =>
      _ScreenCompanyProfileBankSettingsState();
}

class _ScreenCompanyProfileBankSettingsState
    extends State<ScreenCompanyProfileBankSettings> {
  static const Color _primary = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF16A34A);
  static const Color _red = Color(0xFFDC2626);

  final _formKey = GlobalKey<FormState>();

  final _companyNameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _cinCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _iecCtrl = TextEditingController();
  final _lutNumberCtrl = TextEditingController();
  final _adCodeCtrl = TextEditingController();

  final List<_BankDraft> _banks = [];

  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _companyRef =>
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId);

  String _text(dynamic value) => (value ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _legalNameCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _cinCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCodeCtrl.dispose();
    _countryCtrl.dispose();
    _iecCtrl.dispose();
    _lutNumberCtrl.dispose();
    _adCodeCtrl.dispose();

    for (final bank in _banks) {
      bank.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _companyRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      _companyNameCtrl.text = _text(data['companyName'] ?? data['name']);
      _legalNameCtrl.text = _text(data['legalName'] ?? data['entityName']);
      _gstCtrl.text = _text(data['gstin'] ?? data['gstNo'] ?? data['gst']);
      _panCtrl.text = _text(data['pan'] ?? data['panNo']);
      _cinCtrl.text = _text(data['cin']);
      _emailCtrl.text = _text(data['email']);
      _phoneCtrl.text = _text(data['phone'] ?? data['mobile']);
      _websiteCtrl.text = _text(data['website']);
      _addressCtrl.text = _text(
        data['streetAddress'] ?? data['address'] ?? data['registeredAddress'],
      );
      _cityCtrl.text = _text(data['city'] ?? data['district']);
      _stateCtrl.text = _text(data['state']);
      _postalCodeCtrl.text = _text(
        data['postalCode'] ?? data['pincode'] ?? data['zip'],
      );
      _countryCtrl.text = _text(data['country']).isEmpty
          ? 'India'
          : _text(data['country']);
      _iecCtrl.text = _text(data['iec'] ?? data['iecCode']);
      _lutNumberCtrl.text = _text(data['lutNumber']);
      _adCodeCtrl.text = _text(data['adCode']);

      final rawAccounts = data['bankAccounts'];
      if (rawAccounts is List) {
        for (final item in rawAccounts) {
          if (item is Map) {
            _banks.add(_BankDraft.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      }

      if (_banks.isEmpty) {
        final legacyBankDetails = data['bankDetails'];
        final legacy = legacyBankDetails is Map
            ? Map<String, dynamic>.from(legacyBankDetails)
            : <String, dynamic>{};

        final bank = _BankDraft();
        bank.id = DateTime.now().millisecondsSinceEpoch.toString();
        bank.accountLabel.text = 'Default Account';
        bank.bankName.text = _text(legacy['bankName'] ?? data['bankName']);
        bank.accountHolder.text = _text(
          legacy['accountHolder'] ?? data['accountHolderName'],
        );
        bank.accountNumber.text = _text(
          legacy['accountNumber'] ?? data['accountNumber'],
        );
        bank.ifsc.text = _text(
          legacy['ifsc'] ?? data['ifsc'] ?? data['ifscCode'],
        );
        bank.branch.text = _text(legacy['branch'] ?? data['branch']);
        bank.swiftCode.text = _text(legacy['swiftCode'] ?? data['swiftCode']);
        bank.bankAddress.text = _text(
          legacy['bankAddress'] ?? data['bankAddress'],
        );
        bank.isDefault = true;
        _banks.add(bank);
      }

      if (!_banks.any((bank) => bank.isDefault) && _banks.isNotEmpty) {
        _banks.first.isDefault = true;
      }
    } catch (e) {
      _snack('Failed to load company profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addBank() {
    setState(() {
      final bank = _BankDraft();
      bank.id = DateTime.now().millisecondsSinceEpoch.toString();
      bank.accountLabel.text = 'Bank Account ${_banks.length + 1}';
      bank.isDefault = _banks.isEmpty;
      _banks.add(bank);
    });
  }

  void _removeBank(int index) {
    if (_banks.length == 1) {
      _snack('At least one bank account is required.', isError: true);
      return;
    }

    setState(() {
      final wasDefault = _banks[index].isDefault;
      _banks[index].dispose();
      _banks.removeAt(index);
      if (wasDefault && _banks.isNotEmpty) {
        _banks.first.isDefault = true;
      }
    });
  }

  void _setDefaultBank(int index) {
    setState(() {
      for (int i = 0; i < _banks.length; i++) {
        _banks[i].isDefault = i == index;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_banks.isEmpty) {
      _snack('Please add at least one bank account.', isError: true);
      return;
    }

    final validBanks = _banks.where((bank) {
      return bank.bankName.text.trim().isNotEmpty ||
          bank.accountNumber.text.trim().isNotEmpty ||
          bank.ifsc.text.trim().isNotEmpty;
    }).toList();

    if (validBanks.isEmpty) {
      _snack(
        'Please enter bank name, account number, and IFSC.',
        isError: true,
      );
      return;
    }

    if (!validBanks.any((bank) => bank.isDefault)) {
      validBanks.first.isDefault = true;
    }

    setState(() => _saving = true);

    try {
      final bankAccounts = validBanks.map((bank) => bank.toMap()).toList();
      final defaultBank = validBanks.firstWhere((bank) => bank.isDefault);
      final defaultBankMap = defaultBank.toMap();

      await _companyRef.set({
        'companyName': _companyNameCtrl.text.trim(),
        'name': _companyNameCtrl.text.trim(),
        'legalName': _legalNameCtrl.text.trim(),
        'entityName': _legalNameCtrl.text.trim(),
        'gstin': _gstCtrl.text.trim(),
        'gstNo': _gstCtrl.text.trim(),
        'gst': _gstCtrl.text.trim(),
        'pan': _panCtrl.text.trim(),
        'panNo': _panCtrl.text.trim(),
        'cin': _cinCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'mobile': _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'streetAddress': _addressCtrl.text.trim(),
        'registeredAddress': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'district': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'postalCode': _postalCodeCtrl.text.trim(),
        'pincode': _postalCodeCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'iec': _iecCtrl.text.trim(),
        'iecCode': _iecCtrl.text.trim(),
        'lutNumber': _lutNumberCtrl.text.trim(),
        'adCode': _adCodeCtrl.text.trim(),

        // New structure
        'bankAccounts': bankAccounts,
        'defaultBankAccountId': defaultBank.id,

        // Backward-compatible fields for old quotation/invoice screens
        'bankDetails': defaultBankMap,
        'bankName': defaultBank.bankName.text.trim(),
        'accountHolderName': defaultBank.accountHolder.text.trim(),
        'accountNumber': defaultBank.accountNumber.text.trim(),
        'ifsc': defaultBank.ifsc.text.trim(),
        'ifscCode': defaultBank.ifsc.text.trim(),
        'branch': defaultBank.branch.text.trim(),
        'swiftCode': defaultBank.swiftCode.text.trim(),
        'bankAddress': defaultBank.bankAddress.text.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _snack('Company profile and bank details saved.');
    } catch (e) {
      _snack('Failed to save profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _red : _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    IconData? icon,
    int maxLines = 1,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: required
          ? (value) =>
                (value ?? '').trim().isEmpty ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Company Profile & Banking'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _section(
              title: 'Company Identity',
              subtitle:
                  'These details are used in quotations, invoices, and ERP documents.',
              child: _responsiveGrid([
                _field(
                  _companyNameCtrl,
                  'Company Name',
                  icon: Icons.business,
                  required: true,
                ),
                _field(
                  _legalNameCtrl,
                  'Legal Name',
                  icon: Icons.verified_outlined,
                ),
                _field(_gstCtrl, 'GSTIN', icon: Icons.receipt_long_outlined),
                _field(_panCtrl, 'PAN', icon: Icons.badge_outlined),
                _field(
                  _cinCtrl,
                  'CIN',
                  icon: Icons.confirmation_number_outlined,
                ),
                _field(
                  _iecCtrl,
                  'IEC Code',
                  icon: Icons.import_export_outlined,
                ),
              ]),
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Contact & Address',
              subtitle: 'Registered address and contact details.',
              child: Column(
                children: [
                  _responsiveGrid([
                    _field(_emailCtrl, 'Email', icon: Icons.email_outlined),
                    _field(_phoneCtrl, 'Phone', icon: Icons.phone_outlined),
                    _field(
                      _websiteCtrl,
                      'Website',
                      icon: Icons.language_outlined,
                    ),
                    _field(_stateCtrl, 'State', icon: Icons.map_outlined),
                    _field(
                      _cityCtrl,
                      'City',
                      icon: Icons.location_city_outlined,
                    ),
                    _field(
                      _postalCodeCtrl,
                      'Pincode',
                      icon: Icons.pin_drop_outlined,
                    ),
                    _field(
                      _countryCtrl,
                      'Country',
                      icon: Icons.public_outlined,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _field(
                    _addressCtrl,
                    'Registered Address',
                    icon: Icons.place_outlined,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Export / Tax References',
              subtitle:
                  'Used in export invoices and tax documents where applicable.',
              child: _responsiveGrid([
                _field(
                  _lutNumberCtrl,
                  'LUT Number',
                  icon: Icons.description_outlined,
                ),
                _field(
                  _adCodeCtrl,
                  'AD Code',
                  icon: Icons.account_balance_outlined,
                ),
              ]),
            ),
            const SizedBox(height: 16),
            _banksSection(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _responsiveGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 560
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _banksSection() {
    return _section(
      title: 'Bank Accounts',
      subtitle:
          'Add multiple accounts. The default account is copied to old invoice fields automatically.',
      child: Column(
        children: [
          for (int i = 0; i < _banks.length; i++) _bankCard(i, _banks[i]),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addBank,
              icon: const Icon(Icons.add),
              label: const Text('Add Bank Account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bankCard(int index, _BankDraft bank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(
          color: bank.isDefault ? _blue : _border,
          width: bank.isDefault ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                color: bank.isDefault ? _blue : _primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bank.isDefault
                      ? 'Default Bank Account'
                      : 'Bank Account ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _primary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _setDefaultBank(index),
                icon: Icon(bank.isDefault ? Icons.star : Icons.star_border),
                label: Text(bank.isDefault ? 'Default' : 'Set Default'),
              ),
              IconButton(
                onPressed: () => _removeBank(index),
                icon: const Icon(Icons.delete_outline, color: _red),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _responsiveGrid([
            _field(
              bank.accountLabel,
              'Account Label',
              icon: Icons.label_outline,
            ),
            _field(
              bank.bankName,
              'Bank Name',
              icon: Icons.account_balance_outlined,
              required: bank.isDefault,
            ),
            _field(
              bank.accountHolder,
              'Account Holder',
              icon: Icons.person_outline,
            ),
            _field(
              bank.accountNumber,
              'Account Number',
              icon: Icons.numbers,
              required: bank.isDefault,
            ),
            _field(
              bank.ifsc,
              'IFSC / RTGS Code',
              icon: Icons.code,
              required: bank.isDefault,
            ),
            _field(bank.branch, 'Branch', icon: Icons.location_city_outlined),
            _field(bank.swiftCode, 'SWIFT Code', icon: Icons.public_outlined),
          ]),
          const SizedBox(height: 12),
          _field(
            bank.bankAddress,
            'Bank Address',
            icon: Icons.place_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _BankDraft {
  String id = '';
  bool isDefault = false;

  final accountLabel = TextEditingController();
  final bankName = TextEditingController();
  final accountHolder = TextEditingController();
  final accountNumber = TextEditingController();
  final ifsc = TextEditingController();
  final branch = TextEditingController();
  final swiftCode = TextEditingController();
  final bankAddress = TextEditingController();

  _BankDraft();

  factory _BankDraft.fromMap(Map<String, dynamic> map) {
    final bank = _BankDraft();
    bank.id = (map['id'] ?? DateTime.now().microsecondsSinceEpoch).toString();
    bank.isDefault = map['isDefault'] == true;
    bank.accountLabel.text = (map['accountLabel'] ?? map['label'] ?? '')
        .toString();
    bank.bankName.text = (map['bankName'] ?? '').toString();
    bank.accountHolder.text =
        (map['accountHolder'] ?? map['accountHolderName'] ?? '').toString();
    bank.accountNumber.text = (map['accountNumber'] ?? '').toString();
    bank.ifsc.text = (map['ifsc'] ?? map['ifscCode'] ?? '').toString();
    bank.branch.text = (map['branch'] ?? '').toString();
    bank.swiftCode.text = (map['swiftCode'] ?? '').toString();
    bank.bankAddress.text = (map['bankAddress'] ?? '').toString();
    return bank;
  }

  Map<String, dynamic> toMap() {
    final safeId = id.trim().isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : id.trim();

    return {
      'id': safeId,
      'accountLabel': accountLabel.text.trim(),
      'bankName': bankName.text.trim(),
      'accountHolder': accountHolder.text.trim(),
      'accountHolderName': accountHolder.text.trim(),
      'accountNumber': accountNumber.text.trim(),
      'ifsc': ifsc.text.trim(),
      'ifscCode': ifsc.text.trim(),
      'branch': branch.text.trim(),
      'swiftCode': swiftCode.text.trim(),
      'bankAddress': bankAddress.text.trim(),
      'isDefault': isDefault,
    };
  }

  void dispose() {
    accountLabel.dispose();
    bankName.dispose();
    accountHolder.dispose();
    accountNumber.dispose();
    ifsc.dispose();
    branch.dispose();
    swiftCode.dispose();
    bankAddress.dispose();
  }
}
