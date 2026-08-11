import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/theme_controller.dart';
import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_theme.dart';

import '../controllers/income_tax_controller.dart';
import '../presentation/income_tax_calculator_screen.dart';
import '../repositories/firestore_income_tax_repository.dart';

/// Route this widget from the existing MEMCO Compliance navigation shell.
///
/// Keep companyId and userId sourced from the authenticated workspace context.
class IncomeTaxModuleEntry extends StatefulWidget {
  const IncomeTaxModuleEntry({
    super.key,
    required this.companyId,
    required this.userId,
    this.onToggleTheme,
    this.onFileReady,
    this.canSave = true,
    this.canExport = true,
    this.canDelete = true,
  });

  final String companyId;
  final String userId;
  final VoidCallback? onToggleTheme;
  final IncomeTaxFileHandler? onFileReady;
  final bool canSave;
  final bool canExport;
  final bool canDelete;

  @override
  State<IncomeTaxModuleEntry> createState() => _IncomeTaxModuleEntryState();
}

class _IncomeTaxModuleEntryState extends State<IncomeTaxModuleEntry> {
  late final IncomeTaxController _controller;

  @override
  void initState() {
    super.initState();
    _controller = IncomeTaxController(
      companyId: widget.companyId,
      userId: widget.userId,
      repository: FirestoreIncomeTaxRepository(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ComplianceThemeShell(
      child: IncomeTaxCalculatorScreen(
        controller: _controller,
        onToggleTheme:
            widget.onToggleTheme ??
            () => QuikThemeController.instance.toggle(context),
        onFileReady: widget.onFileReady,
        canSave: widget.canSave,
        canExport: widget.canExport,
        canDelete: widget.canDelete,
      ),
    );
  }
}
