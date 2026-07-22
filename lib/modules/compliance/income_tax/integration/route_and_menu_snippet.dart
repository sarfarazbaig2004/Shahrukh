// EXAMPLE ONLY: adapt names to the routing and permission APIs already used by MEMCO.
// Do not create a second navigation system.

/*
Compliance menu item:

ComplianceMenuItem(
  id: 'income_tax_calculator',
  title: 'Income Tax Calculator',
  icon: Icons.calculate_outlined,
  permission: 'compliance.income_tax.view',
  routeName: '/compliance/income-tax-calculator',
),

Route builder:

GoRoute(
  path: '/compliance/income-tax-calculator',
  builder: (context, state) {
    final session = context.read<SessionProvider>();
    final permissions = context.read<PermissionProvider>();

    return IncomeTaxModuleEntry(
      companyId: session.companyId,
      userId: session.userId,
      canSave: permissions.can('compliance.income_tax.save'),
      canExport: permissions.can('compliance.income_tax.export'),
      canDelete: permissions.can('compliance.income_tax.delete'),
      onToggleTheme: () => context.read<ThemeProvider>().toggleTheme(),
      onFileReady: (filename, bytes, mimeType) async {
        await context.read<FileExportService>().saveOrShare(
          filename: filename,
          bytes: bytes,
          mimeType: mimeType,
        );
      },
    );
  },
),
*/
