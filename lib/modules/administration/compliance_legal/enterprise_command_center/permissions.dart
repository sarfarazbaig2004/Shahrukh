class CommandCenterPermissions {
  const CommandCenterPermissions({
    required this.view,
    required this.create,
    required this.edit,
    required this.delete,
    required this.approve,
    required this.reject,
    required this.print,
    required this.export,
    required this.share,
    required this.configure,
    required this.viewAudit,
    required this.manageSecurity,
  });

  final bool view;
  final bool create;
  final bool edit;
  final bool delete;
  final bool approve;
  final bool reject;
  final bool print;
  final bool export;
  final bool share;
  final bool configure;
  final bool viewAudit;
  final bool manageSecurity;

  const CommandCenterPermissions.readOnly()
    : view = true,
      create = false,
      edit = false,
      delete = false,
      approve = false,
      reject = false,
      print = false,
      export = false,
      share = false,
      configure = false,
      viewAudit = false,
      manageSecurity = false;

  factory CommandCenterPermissions.fromLegacy({
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
    required bool canApprove,
    required bool canExport,
    required bool canUpload,
    required bool canDownload,
  }) => CommandCenterPermissions(
    view: true,
    create: canCreate || canUpload,
    edit: canEdit,
    delete: canDelete,
    approve: canApprove,
    reject: canApprove,
    print: canExport,
    export: canExport,
    share: canExport || canDownload,
    configure: canEdit || canApprove,
    viewAudit: canApprove || canExport,
    manageSecurity: canEdit && canApprove,
  );

  bool can(String action) => switch (action) {
    'view' => view,
    'create' => create,
    'edit' => edit,
    'delete' => delete,
    'approve' => approve,
    'reject' => reject,
    'print' => print,
    'export' => export,
    'share' => share,
    'configure' => configure,
    'viewAudit' => viewAudit,
    'manageSecurity' => manageSecurity,
    _ => false,
  };
}
