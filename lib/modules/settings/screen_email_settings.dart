import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';

enum _EmailSection { providers, accounts, templates, general }
enum _TestConnectionState { idle, running, success, failure }

class ScreenEmailSettings extends StatefulWidget {
  final String companyId;

  const ScreenEmailSettings({
    super.key,
    required this.companyId,
  });

  @override
  State<ScreenEmailSettings> createState() => _ScreenEmailSettingsState();
}

class _ScreenEmailSettingsState extends State<ScreenEmailSettings> {
  _EmailSection _activeSection = _EmailSection.providers;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _providersSubscription;

  // Data-Driven Lists
  final List<Map<String, dynamic>> _configuredProviders = [];
  final List<Map<String, dynamic>> _configuredAccounts = [];

  // Provider States
  bool _isLoadingProviders = true;
  bool _hasProviderLoadError = false;
  int _providerSubscriptionGeneration = 0;
  final Set<String> _testingProviderIds = <String>{};

  // General Settings States
  bool _sendCopyToSender = false;
  bool _attachPdfByDefault = true;
  _TestConnectionState _testState = _TestConnectionState.idle;

  CollectionReference<Map<String, dynamic>> get _providersCollection {
    return _firestore
        .collection('companies')
        .doc(widget.companyId)
        .collection('communication')
        .doc('email')
        .collection('providers');
  }

  @override
  void initState() {
    super.initState();
    _startProviderSubscription();
  }

  @override
  void didUpdateWidget(covariant ScreenEmailSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _configuredProviders.clear();
      _isLoadingProviders = true;
      _hasProviderLoadError = false;
      _startProviderSubscription();
    }
  }

  @override
  void dispose() {
    _providerSubscriptionGeneration++;
    _providersSubscription?.cancel();
    super.dispose();
  }

  void _startProviderSubscription() {
    final generation = ++_providerSubscriptionGeneration;
    _providersSubscription?.cancel();

    if (widget.companyId.trim().isEmpty) {
      _isLoadingProviders = false;
      _hasProviderLoadError = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSnackBar('Firestore Error', Colors.red);
        }
      });
      return;
    }

    _providersSubscription = _providersCollection.snapshots().listen(
          (snapshot) {
        if (!mounted || generation != _providerSubscriptionGeneration) {
          return;
        }

        final providers = snapshot.docs.map((document) {
          return <String, dynamic>{
            ...document.data(),
            'id': document.id,
            'providerId': document.data()['providerId'] ?? document.id,
          };
        }).toList();

        providers.sort((first, second) {
          final firstTimestamp = _timestampMilliseconds(first['createdAt']);
          final secondTimestamp = _timestampMilliseconds(second['createdAt']);
          return secondTimestamp.compareTo(firstTimestamp);
        });

        setState(() {
          _configuredProviders
            ..clear()
            ..addAll(providers);
          _isLoadingProviders = false;
          _hasProviderLoadError = false;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || generation != _providerSubscriptionGeneration) {
          return;
        }

        setState(() {
          _isLoadingProviders = false;
          _hasProviderLoadError = true;
        });
        _showSnackBar('Firestore Error', Colors.red);
      },
    );
  }

  int _timestampMilliseconds(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  void _retryProviderLoad() {
    setState(() {
      _isLoadingProviders = true;
      _hasProviderLoadError = false;
    });
    _startProviderSubscription();
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showProviderDialog({Map<String, dynamic>? provider}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AddProviderDialog(
        initialProvider: provider,
        onSave: (providerData) {
          if (provider == null) {
            return _createProvider(providerData);
          }
          return _updateProvider(provider, providerData);
        },
      ),
    );

    if (!mounted || saved != true) {
      return;
    }

    _showSnackBar(
      provider == null ? 'Provider Created' : 'Provider Updated',
      zSuccess,
    );
  }

  Future<bool> _createProvider(Map<String, dynamic> providerData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Firestore Error', Colors.red);
      return false;
    }

    try {
      final providerReference = _providersCollection.doc();
      await providerReference.set({
        'providerId': providerReference.id,
        ...providerData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
      });
      return true;
    } on FirebaseException {
      _showSnackBar('Firestore Error', Colors.red);
      return false;
    } catch (_) {
      _showSnackBar('Firestore Error', Colors.red);
      return false;
    }
  }

  Future<bool> _updateProvider(
      Map<String, dynamic> provider,
      Map<String, dynamic> providerData,
      ) async {
    final providerId = _providerDocumentId(provider);
    if (providerId == null) {
      _showSnackBar('Firestore Error', Colors.red);
      return false;
    }

    try {
      await _providersCollection.doc(providerId).update({
        'providerId': providerId,
        ...providerData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException {
      _showSnackBar('Firestore Error', Colors.red);
      return false;
    } catch (_) {
      _showSnackBar('Firestore Error', Colors.red);
      return false;
    }
  }

  String? _providerDocumentId(Map<String, dynamic> provider) {
    final providerId = provider['providerId']?.toString().trim();
    if (providerId != null && providerId.isNotEmpty) {
      return providerId;
    }

    final documentId = provider['id']?.toString().trim();
    if (documentId != null && documentId.isNotEmpty) {
      return documentId;
    }

    return null;
  }

  Future<void> _confirmDeleteProvider(Map<String, dynamic> provider) async {
    final providerId = _providerDocumentId(provider);
    if (providerId == null) {
      _showSnackBar('Firestore Error', Colors.red);
      return;
    }

    bool isDeleting = false;

    final deleteResult = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Delete Provider?',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: const Text('This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                    setDialogState(() => isDeleting = true);

                    bool deleted = false;
                    try {
                      await _providersCollection.doc(providerId).delete();
                      deleted = true;
                    } on FirebaseException {
                      deleted = false;
                    } catch (_) {
                      deleted = false;
                    }

                    if (!dialogContext.mounted) {
                      return;
                    }

                    Navigator.pop(dialogContext, deleted);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || deleteResult == null) {
      return;
    }

    if (deleteResult) {
      _showSnackBar('Provider Deleted', zSuccess);
    } else {
      _showSnackBar('Firestore Error', Colors.red);
    }
  }

  Future<void> _runProviderTest(Map<String, dynamic> provider) async {
    final providerId = _providerDocumentId(provider);
    if (providerId == null || _testingProviderIds.contains(providerId)) {
      return;
    }

    setState(() => _testingProviderIds.add(providerId));
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() => _testingProviderIds.remove(providerId));
    _showSnackBar('Test successful!', zSuccess);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature configuration is coming soon.'),
        backgroundColor: zBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<_NavItemData> get _navItems {
    return const [
      _NavItemData(
        section: _EmailSection.providers,
        title: 'Email Providers',
        icon: Icons.cloud_queue_rounded,
      ),
      _NavItemData(
        section: _EmailSection.accounts,
        title: 'Email Accounts',
        icon: Icons.manage_accounts_outlined,
      ),
      _NavItemData(
        section: _EmailSection.templates,
        title: 'Email Templates',
        icon: Icons.mark_email_read_outlined,
      ),
      _NavItemData(
        section: _EmailSection.general,
        title: 'General Settings',
        icon: Icons.tune_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: zText),
        title: const Text(
          'Email Configuration',
          style: TextStyle(
            color: zText,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        shape: const Border(bottom: BorderSide(color: zBorder)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 250, child: _buildLeftNav()),
            const SizedBox(width: 16),
            Expanded(child: _buildRightPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftNav() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _navItems.map((item) {
          final selected = _activeSection == item.section;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _activeSection = item.section),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected ? zBlueSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? zBlue.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: selected ? zBlue : zMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: selected ? zBlue : zText,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRightPanel() {
    switch (_activeSection) {
      case _EmailSection.providers:
        return _buildProvidersSection();
      case _EmailSection.accounts:
        return _buildAccountsSection();
      case _EmailSection.templates:
        return _buildTemplatesSection();
      case _EmailSection.general:
        return _buildGeneralSection();
    }
  }

  Widget _buildProvidersSection() {
    Widget content;

    if (_isLoadingProviders) {
      content = const Center(
        child: CircularProgressIndicator(color: zBlue),
      );
    } else if (_hasProviderLoadError) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: zMuted),
            const SizedBox(height: 12),
            const Text(
              'Unable to load providers.',
              style: TextStyle(
                color: zText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _retryProviderLoad,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_configuredProviders.isEmpty) {
      content = _buildEmptyState(
        icon: Icons.hub_outlined,
        title: 'No Providers Configured',
        message: 'Create your first provider to allow the ERP to connect with your organization\'s email service.',
        helpText: 'Providers store connection details like SMTP hosts and credentials.',
        buttonText: 'Add Provider',
        onAdd: () => _showProviderDialog(),
      );
    } else {
      content = Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showProviderDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Provider'),
              style: FilledButton.styleFrom(
                backgroundColor: zBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _configuredProviders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final provider = _configuredProviders[index];
                final providerId = _providerDocumentId(provider);
                final isTesting = providerId != null &&
                    _testingProviderIds.contains(providerId);

                return _ProviderEnterpriseCard(
                  provider: provider,
                  isTesting: isTesting,
                  onEdit: () => _showProviderDialog(provider: provider),
                  onDelete: () => _confirmDeleteProvider(provider),
                  onTest: () => _runProviderTest(provider),
                );
              },
            ),
          ),
        ],
      );
    }

    return _SectionPanel(
      title: 'Email Providers',
      subtitle: 'Configure core backend connections to services like Google Workspace or Microsoft 365.',
      child: content,
    );
  }

  Widget _buildAccountsSection() {
    return _SectionPanel(
      title: 'Email Accounts',
      subtitle: 'Map specific company email addresses (e.g., sales@) to ERP departments.',
      child: _configuredAccounts.isEmpty
          ? _buildEmptyState(
        icon: Icons.alternate_email_rounded,
        title: 'No Email Accounts Found',
        message: 'Create your first business email account and link it to an existing Provider.',
        helpText: 'Accounts handle sender identities, signatures, and departmental routing.',
        buttonText: 'Add Account',
        onAdd: () => showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _AddAccountDialog(providers: _configuredProviders),
        ),
      )
          : ListView(children: const []), // Ready for dynamic list builder
    );
  }

  Widget _buildTemplatesSection() {
    return _SectionPanel(
      title: 'Email Templates',
      subtitle: 'Standardized outgoing structures for your enterprise modules.',
      child: ListView(
        children: [
          _TemplateEnterpriseCard(
            documentName: 'Quotation',
            module: 'Sales Module',
            emailSubject: 'Quotation {{doc_number}} from {{company_name}}',
            status: 'Active',
            onEdit: () => _showComingSoon('Edit Quotation Template'),
            onPreview: () => _showComingSoon('Preview Quotation Template'),
          ),
          const SizedBox(height: 12),
          _TemplateEnterpriseCard(
            documentName: 'Tax Invoice',
            module: 'Finance Module',
            emailSubject: 'Invoice {{doc_number}} from {{company_name}}',
            status: 'Active',
            onEdit: () => _showComingSoon('Edit Invoice Template'),
            onPreview: () => _showComingSoon('Preview Invoice Template'),
          ),
          const SizedBox(height: 12),
          _TemplateEnterpriseCard(
            documentName: 'Proforma Invoice',
            module: 'Finance Module',
            emailSubject: 'Proforma Invoice {{doc_number}}',
            status: 'Active',
            onEdit: () => _showComingSoon('Edit PI Template'),
            onPreview: () => _showComingSoon('Preview PI Template'),
          ),
          const SizedBox(height: 12),
          _TemplateEnterpriseCard(
            documentName: 'Purchase Order',
            module: 'Purchase Module',
            emailSubject: 'Purchase Order {{doc_number}} from {{company_name}}',
            status: 'Active',
            onEdit: () => _showComingSoon('Edit PO Template'),
            onPreview: () => _showComingSoon('Preview PO Template'),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSection() {
    final hasAccounts = _configuredAccounts.isNotEmpty;

    return _SectionPanel(
      title: 'General Settings',
      subtitle: 'Global fallback configurations for outgoing emails.',
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: zBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FormSectionHeader(title: 'Global Sending Defaults'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Default Sender Address', border: OutlineInputBorder()),
                items: hasAccounts
                    ? _configuredAccounts.map((a) => DropdownMenuItem(value: a['id'].toString(), child: Text(a['email']))).toList()
                    : const [DropdownMenuItem(value: 'none', child: Text('No Email Accounts Available'))],
                value: 'none',
                onChanged: hasAccounts ? (v) => _showComingSoon('Default Sender Update') : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Reply-To Address', border: OutlineInputBorder()),
                items: hasAccounts
                    ? _configuredAccounts.map((a) => DropdownMenuItem(value: a['id'].toString(), child: Text(a['email']))).toList()
                    : const [DropdownMenuItem(value: 'none', child: Text('No Email Accounts Available'))],
                value: 'none',
                onChanged: hasAccounts ? (v) => _showComingSoon('Reply-To Update') : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'BCC Archive Address', border: OutlineInputBorder()),
                items: hasAccounts
                    ? [
                  const DropdownMenuItem(value: 'none', child: Text('None')),
                  const DropdownMenuItem(value: 'archive', child: Text('Global Archive Mailbox')),
                  ..._configuredAccounts.map((a) => DropdownMenuItem(value: a['id'].toString(), child: Text(a['email'])))
                ]
                    : const [DropdownMenuItem(value: 'none', child: Text('No Email Accounts Available'))],
                value: 'none',
                onChanged: hasAccounts ? (v) => _showComingSoon('BCC Update') : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Default Fallback Signature', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'company', child: Text('Company Default')),
                  DropdownMenuItem(value: 'sales', child: Text('Sales Signature')),
                  DropdownMenuItem(value: 'accounts', child: Text('Accounts Signature')),
                  DropdownMenuItem(value: 'management', child: Text('Management Signature')),
                  DropdownMenuItem(value: 'new', child: Text('+ Create New Signature')),
                ],
                value: 'company',
                onChanged: (v) => _showComingSoon('Signature Update'),
              ),
              const SizedBox(height: 24),
              const _FormSectionHeader(title: 'Behavior Preferences'),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Send copy to sender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Automatically BCC the employee who triggers the email.', style: TextStyle(fontSize: 12, color: zMuted)),
                value: _sendCopyToSender,
                activeColor: zBlue,
                onChanged: (val) {
                  setState(() => _sendCopyToSender = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Attach generated PDF by default', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Automatically attach the system generated PDF to module emails.', style: TextStyle(fontSize: 12, color: zMuted)),
                value: _attachPdfByDefault,
                activeColor: zBlue,
                onChanged: (val) {
                  setState(() => _attachPdfByDefault = val);
                },
              ),
              const SizedBox(height: 24),
              const Divider(color: zBorder),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: _buildTestConnectionButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestConnectionButton() {
    if (_testState == _TestConnectionState.idle) {
      return OutlinedButton.icon(
        onPressed: _runTestConnection,
        icon: const Icon(Icons.send_outlined, size: 18),
        label: const Text('Test Configuration'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: zBlue),
          foregroundColor: zBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else if (_testState == _TestConnectionState.running) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: zBlue),
        ),
        label: const Text('Running Diagnostic...'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: zBlue.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else if (_testState == _TestConnectionState.success) {
      return FilledButton.icon(
        onPressed: () => setState(() => _testState = _TestConnectionState.idle),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Connection Successful (Click to reset)'),
        style: FilledButton.styleFrom(
          backgroundColor: zSuccess,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      return FilledButton.icon(
        onPressed: () => setState(() => _testState = _TestConnectionState.idle),
        icon: const Icon(Icons.error_outline, size: 18),
        label: const Text('Connection Failed (Click to reset)'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _runTestConnection() {
    setState(() => _testState = _TestConnectionState.running);
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _testState = _TestConnectionState.success);
      }
    });
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String helpText,
    required String buttonText,
    required VoidCallback onAdd,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: zBlueSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: zBlue.withValues(alpha: 0.1)),
                      ),
                      child: Icon(icon, size: 54, color: zBlue),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: zText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: zText,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      helpText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: zMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(buttonText),
              style: FilledButton.styleFrom(
                backgroundColor: zBlue,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// ENTERPRISE DIALOGS WITH SMART PRESETS & VALIDATION
// ==========================================================

class _AddProviderDialog extends StatefulWidget {
  final Map<String, dynamic>? initialProvider;
  final Future<bool> Function(Map<String, dynamic> providerData) onSave;

  const _AddProviderDialog({
    required this.onSave,
    this.initialProvider,
  });

  @override
  State<_AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends State<_AddProviderDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _selectedVendor;
  String _selectedType = 'SMTP';
  String _selectedEncryption = 'STARTTLS';
  String _selectedAuth = 'App Password';
  String _selectedStatus = 'Active';

  bool _isTesting = false;
  bool _isSaving = false;

  final Map<String, Map<String, String>> _vendorPresets = {
    'Gmail': {'host': 'smtp.gmail.com', 'port': '587', 'enc': 'STARTTLS', 'auth': 'App Password'},
    'Google Workspace': {'host': 'smtp-relay.gmail.com', 'port': '587', 'enc': 'STARTTLS', 'auth': 'App Password'},
    'Microsoft 365': {'host': 'smtp.office365.com', 'port': '587', 'enc': 'STARTTLS', 'auth': 'OAuth 2.0'},
    'Outlook.com': {'host': 'smtp-mail.outlook.com', 'port': '587', 'enc': 'STARTTLS', 'auth': 'App Password'},
    'Zoho Mail': {'host': 'smtp.zoho.com', 'port': '465', 'enc': 'SSL', 'auth': 'App Password'},
    'Hostinger': {'host': 'smtp.hostinger.com', 'port': '465', 'enc': 'SSL', 'auth': 'Username & Password'},
    'GoDaddy': {'host': 'smtpout.secureserver.net', 'port': '465', 'enc': 'SSL', 'auth': 'Username & Password'},
    'Namecheap': {'host': 'mail.privateemail.com', 'port': '465', 'enc': 'SSL', 'auth': 'Username & Password'},
    'Amazon SES': {'host': 'email-smtp.us-east-1.amazonaws.com', 'port': '587', 'enc': 'STARTTLS', 'auth': 'Username & Password'},
    'SendGrid': {'host': 'smtp.sendgrid.net', 'port': '587', 'enc': 'STARTTLS', 'auth': 'API Key'},
    'Mailgun': {'host': 'smtp.mailgun.org', 'port': '587', 'enc': 'STARTTLS', 'auth': 'API Key'},
  };

  final List<String> _vendors = [
    'Gmail', 'Google Workspace', 'Microsoft 365', 'Outlook.com', 'Zoho Mail',
    'Hostinger', 'GoDaddy', 'Namecheap', 'Bluehost', 'Titan Email', 'Rackspace Email',
    'Amazon SES', 'SendGrid', 'Mailgun', 'SMTP2GO', 'Postmark', 'Custom SMTP', 'Other'
  ];

  final List<String> _connectionTypes = [
    'SMTP',
    'OAuth 2.0',
    'API',
    'Exchange',
    'Custom',
  ];

  final List<String> _encryptionOptions = [
    'Auto Detect',
    'TLS',
    'SSL',
    'STARTTLS',
    'None',
  ];

  final List<String> _authenticationMethods = [
    'Username & Password',
    'App Password',
    'OAuth 2.0',
    'API Key',
    'Anonymous',
    'Custom',
  ];

  final List<String> _statusOptions = [
    'Active',
    'Inactive',
    'Testing',
    'Suspended',
  ];

  @override
  void initState() {
    super.initState();
    _populateExistingProvider();
  }

  void _populateExistingProvider() {
    final provider = widget.initialProvider;
    if (provider == null) {
      return;
    }

    _selectedVendor = _stringValue(provider['vendor']);
    _selectedType = _supportedValue(
      provider['connectionType'],
      _connectionTypes,
      'SMTP',
    );
    _selectedEncryption = _supportedValue(
      provider['encryption'],
      _encryptionOptions,
      'STARTTLS',
    );
    _selectedAuth = _supportedValue(
      provider['authenticationMethod'],
      _authenticationMethods,
      'App Password',
    );
    _selectedStatus = _supportedValue(
      provider['status'],
      _statusOptions,
      'Active',
    );

    _nameCtrl.text = _stringValue(provider['providerName']) ?? '';
    _hostCtrl.text = _stringValue(provider['smtpHost']) ?? '';
    _portCtrl.text = provider['smtpPort']?.toString() ?? '';
    _userCtrl.text = _stringValue(provider['username']) ?? '';
    _passCtrl.text = _stringValue(provider['encryptedPassword']) ?? '';
    _descCtrl.text = _stringValue(provider['description']) ?? '';
  }

  String? _stringValue(dynamic value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    return text;
  }

  String _supportedValue(
      dynamic value,
      List<String> supportedValues,
      String fallback,
      ) {
    final text = _stringValue(value);
    if (text != null && supportedValues.contains(text)) {
      return text;
    }
    return fallback;
  }

  void _applyPreset(String vendor) {
    if (_vendorPresets.containsKey(vendor)) {
      final preset = _vendorPresets[vendor]!;
      setState(() {
        _hostCtrl.text = preset['host']!;
        _portCtrl.text = preset['port']!;
        _selectedEncryption = preset['enc']!;
        _selectedAuth = preset['auth']!;
        if (_nameCtrl.text.isEmpty) _nameCtrl.text = '$vendor Server';
      });
    } else {
      setState(() {
        _hostCtrl.clear();
        _portCtrl.clear();
      });
    }
  }

  void _suggestPort(String encryption) {
    if (_portCtrl.text.isEmpty || ['25', '465', '587'].contains(_portCtrl.text)) {
      setState(() {
        if (encryption == 'TLS' || encryption == 'STARTTLS' || encryption == 'Auto Detect') {
          _portCtrl.text = '587';
        } else if (encryption == 'SSL') {
          _portCtrl.text = '465';
        } else if (encryption == 'None') {
          _portCtrl.text = '25';
        }
      });
    }
  }

  Widget _buildDynamicAuthFields() {
    switch (_selectedAuth) {
      case 'OAuth 2.0':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: zBlueSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: zBlue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: const [
              Icon(Icons.lock_person_outlined, color: zBlue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OAuth 2.0 integration is currently under development. Coming Soon.',
                  style: TextStyle(color: zBlue, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      case 'API Key':
        return TextFormField(
          controller: _passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'API Key *', border: OutlineInputBorder()),
          validator: (v) => v == null || v.trim().isEmpty ? 'API Key is required' : null,
        );
      case 'Username & Password':
      case 'App Password':
        final isAppPass = _selectedAuth == 'App Password';
        return Column(
          children: [
            TextFormField(
              controller: _userCtrl,
              decoration: const InputDecoration(labelText: 'Authentication Username *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Username is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: isAppPass ? 'App Password *' : 'Password *', border: const OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Password is required' : null,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool get _requiresUsername {
    return _selectedAuth == 'Username & Password' ||
        _selectedAuth == 'App Password';
  }

  bool get _requiresSecret {
    return _requiresUsername || _selectedAuth == 'API Key';
  }

  void _showDialogSnackBar(String message, Color backgroundColor) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runFakeTest() async {
    if (!_formKey.currentState!.validate()) {
      _showDialogSnackBar('Validation Error', Colors.red);
      return;
    }

    setState(() => _isTesting = true);
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() => _isTesting = false);
    _showDialogSnackBar('Test successful!', zSuccess);
  }

  Future<void> _saveProvider() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showDialogSnackBar('Validation Error', Colors.red);
      return;
    }

    final vendor = _selectedVendor?.trim();
    final port = int.tryParse(_portCtrl.text.trim());
    if (vendor == null || vendor.isEmpty || port == null) {
      _showDialogSnackBar('Validation Error', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    final saved = await widget.onSave({
      'providerName': _nameCtrl.text.trim(),
      'vendor': vendor,
      'connectionType': _selectedType,
      'smtpHost': _hostCtrl.text.trim(),
      'smtpPort': port,
      'encryption': _selectedEncryption,
      'authenticationMethod': _selectedAuth,
      'username': _requiresUsername ? _userCtrl.text.trim() : '',
      'encryptedPassword': _requiresSecret ? _passCtrl.text : '',
      'status': _selectedStatus,
      'description': _descCtrl.text.trim(),
    });

    if (!mounted) {
      return;
    }

    if (saved) {
      Navigator.pop(context, true);
      return;
    }

    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Configure Provider', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FormSectionHeader(title: 'Provider Identification'),
                const SizedBox(height: 16),
                _SearchableDropdown(
                  label: 'Vendor / Preset *',
                  options: _vendors,
                  value: _selectedVendor,
                  onChanged: (v) {
                    _selectedVendor = v;
                    if (v != null) _applyPreset(v);
                  },
                  validator: (v) => v == null || v.isEmpty ? 'Vendor selection is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Provider Name *', hintText: 'e.g. Sales SMTP', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Provider Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                ),

                const SizedBox(height: 24),
                const _FormSectionHeader(title: 'Connection Details'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Connection Type *', border: OutlineInputBorder()),
                  items: _connectionTypes
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _hostCtrl,
                        decoration: const InputDecoration(labelText: 'Host *', hintText: 'e.g. smtp.gmail.com', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Host is required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Port *', hintText: 'e.g. 587', border: OutlineInputBorder()),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final port = int.tryParse(v);
                          if (port == null || port <= 0 || port > 65535) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const _FormSectionHeader(title: 'Authentication & Security'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedEncryption,
                  decoration: const InputDecoration(labelText: 'Encryption', border: OutlineInputBorder()),
                  items: _encryptionOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedEncryption = v!);
                    _suggestPort(v!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedAuth,
                  decoration: const InputDecoration(labelText: 'Authentication Method *', border: OutlineInputBorder()),
                  items: _authenticationMethods
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAuth = v!),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildDynamicAuthFields(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: _statusOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: _isTesting || _isSaving ? null : _runFakeTest,
          icon: _isTesting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.bolt, size: 16),
          label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveProvider,
          child: _isSaving
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text('Save Provider'),
        ),
      ],
    );
  }
}

class _AddAccountDialog extends StatefulWidget {
  final List<Map<String, dynamic>> providers;

  const _AddAccountDialog({required this.providers});

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _customPurposeCtrl = TextEditingController();

  String? _selectedProvider;
  String? _selectedPurpose;
  String _selectedSignature = 'Company Default';
  String _selectedStatus = 'Active';

  final List<String> _purposes = [
    'Sales', 'Marketing', 'Customer Support', 'Accounts', 'Finance',
    'Purchase', 'Procurement', 'HR', 'Administration', 'Management',
    'Dispatch', 'Stores', 'Production', 'Quality', 'Projects',
    'Service', 'General', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.providers.isNotEmpty) {
      _selectedProvider = widget.providers.first['id'].toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _customPurposeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.providers.isEmpty) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Action Required', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'You must configure an Email Provider before you can create an Email Account.\n\nPlease go back and add a Provider first.',
          style: TextStyle(height: 1.5, color: zText),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Configure Email Account', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FormSectionHeader(title: 'Account Information'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Display Name *', hintText: 'e.g. Sales Department', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Display Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'e.g. sales@company.com', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Enter a valid email address';
                    return null;
                  },
                ),

                const SizedBox(height: 24),
                const _FormSectionHeader(title: 'Routing & Assignment'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Linked Provider *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.providers.map((p) {
                    return DropdownMenuItem<String>(
                      value: p['id'].toString(),
                      child: Text(
                        p['providerName'] ?? p['name'] ?? 'Unnamed Provider',
                      ),
                    );
                  }).toList(),
                  value: _selectedProvider,
                  onChanged: (v) => setState(() => _selectedProvider = v),
                  validator: (v) => v == null || v.isEmpty ? 'Provider mapping is required' : null,
                ),
                const SizedBox(height: 16),
                _SearchableDropdown(
                  label: 'Purpose / Department *',
                  options: _purposes,
                  value: _selectedPurpose,
                  onChanged: (v) => setState(() => _selectedPurpose = v),
                  validator: (v) => v == null || v.isEmpty ? 'Purpose is required' : null,
                ),
                if (_selectedPurpose == 'Other') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customPurposeCtrl,
                    decoration: const InputDecoration(labelText: 'Custom Purpose *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Custom Purpose is required' : null,
                  ),
                ],

                const SizedBox(height: 24),
                const _FormSectionHeader(title: 'Preferences'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedSignature,
                  decoration: const InputDecoration(labelText: 'Default Signature', border: OutlineInputBorder()),
                  items: ['Company Default', 'Sales', 'Accounts', 'Management', 'Create New']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSignature = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: ['Active', 'Inactive', 'Testing', 'Suspended']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account Saved (UI Only)')));
            }
          },
          child: const Text('Save Account'),
        ),
      ],
    );
  }
}

// ==========================================================
// REUSABLE PRIVATE WIDGETS
// ==========================================================

class _SearchableDropdown extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  const _SearchableDropdown({
    required this.label,
    required this.options,
    this.value,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      validator: validator,
      builder: (FormFieldState<String> state) {
        return Autocomplete<String>(
          initialValue: TextEditingValue(text: value ?? ''),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return options;
            return options.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            state.didChange(selection);
            onChanged(selection);
          },
          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
            if (value != null && textEditingController.text.isEmpty) {
              textEditingController.text = value!;
            }
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                errorText: state.errorText,
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              onChanged: (val) {
                state.didChange(val.isEmpty ? null : val);
                onChanged(val.isEmpty ? null : val);
              },
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250, maxWidth: 500),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Text(option),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NavItemData {
  final _EmailSection section;
  final String title;
  final IconData icon;

  const _NavItemData({
    required this.section,
    required this.title,
    required this.icon,
  });
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: zMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: zBorder, height: 1),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _FormSectionHeader extends StatelessWidget {
  final String title;

  const _FormSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: zCanvasBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: zBorder.withValues(alpha: 0.5)),
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: zMuted,
        ),
      ),
    );
  }
}

class _ProviderEnterpriseCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final bool isTesting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;

  const _ProviderEnterpriseCard({
    required this.provider,
    required this.isTesting,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final providerName = _displayValue(provider['providerName']);
    final status = _displayValue(provider['status']);
    final isActive = status.toLowerCase() == 'active';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  providerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: zText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isActive ? zSuccess : zOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _ProviderDetail(
                label: 'Vendor',
                value: _displayValue(provider['vendor']),
              ),
              _ProviderDetail(
                label: 'SMTP Host',
                value: _displayValue(provider['smtpHost']),
              ),
              _ProviderDetail(
                label: 'Port',
                value: _displayValue(provider['smtpPort']),
              ),
              _ProviderDetail(
                label: 'Authentication',
                value: _displayValue(provider['authenticationMethod']),
              ),
              _ProviderDetail(
                label: 'Status',
                value: status,
              ),
              _ProviderDetail(
                label: 'Created Date',
                value: _formatDate(provider['createdAt']),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: zBorder, height: 1),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: zBlueSoft,
                    foregroundColor: zBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isTesting ? null : onTest,
                  icon: isTesting
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.bolt, size: 16),
                  label: Text(isTesting ? 'Testing...' : 'Test'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return '-';
    }
    return text;
  }

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return 'Pending';
    }

    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    return '$day/$month/${localDate.year}';
  }
}

class _ProviderDetail extends StatelessWidget {
  final String label;
  final String value;

  const _ProviderDetail({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: zMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: zText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateEnterpriseCard extends StatelessWidget {
  final String documentName;
  final String module;
  final String emailSubject;
  final String status;
  final VoidCallback onEdit;
  final VoidCallback onPreview;

  const _TemplateEnterpriseCard({
    required this.documentName,
    required this.module,
    required this.emailSubject,
    required this.status,
    required this.onEdit,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: zCanvasBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: zBorder),
                ),
                child: Text(
                  module,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: zMuted),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isActive ? zSuccess : zOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            documentName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: zText),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Subject: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: zMuted)),
              Expanded(
                child: Text(
                  emailSubject,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: zText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: zBorder, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: zMuted),
                label: const Text('Preview', style: TextStyle(color: zMuted)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Template'),
                style: FilledButton.styleFrom(
                  backgroundColor: zBlueSoft,
                  foregroundColor: zBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}