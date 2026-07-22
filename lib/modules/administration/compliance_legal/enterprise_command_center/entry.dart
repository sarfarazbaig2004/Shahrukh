import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/theme_controller.dart';

import '../design_system/compliance_theme.dart';
import 'controller.dart';
import 'permissions.dart';
import 'repository.dart';
import 'screen.dart';
import 'services.dart';

class EnterpriseComplianceCommandCenterEntry extends StatefulWidget {
  const EnterpriseComplianceCommandCenterEntry({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.userId,
    required this.userName,
    required this.permissions,
    this.onExport,
    this.documentService,
    this.notificationService,
  });

  final String companyId;
  final String companyName;
  final String userId;
  final String userName;
  final CommandCenterPermissions permissions;
  final CommandCenterFileHandler? onExport;
  final CommandCenterDocumentService? documentService;
  final CommandCenterNotificationService? notificationService;

  @override
  State<EnterpriseComplianceCommandCenterEntry> createState() =>
      _EnterpriseComplianceCommandCenterEntryState();
}

class _EnterpriseComplianceCommandCenterEntryState
    extends State<EnterpriseComplianceCommandCenterEntry> {
  late final CommandCenterController controller;

  @override
  void initState() {
    super.initState();
    controller = CommandCenterController(
      companyId: widget.companyId,
      companyName: widget.companyName,
      userId: widget.userId,
      userName: widget.userName,
      permissions: widget.permissions,
      repository: FirestoreCommandCenterRepository(),
    )..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ComplianceThemeShell(
      child: EnterpriseComplianceCommandCenterScreen(
        controller: controller,
        onToggleTheme: () => QuikThemeController.instance.toggle(context),
        onExport: widget.onExport,
        documentService: widget.documentService,
        notificationService: widget.notificationService,
      ),
    );
  }
}
