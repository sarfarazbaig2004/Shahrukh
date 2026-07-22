import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'permissions.dart';
import 'repository.dart';
import 'services.dart';

class CommandCenterController extends ChangeNotifier {
  CommandCenterController({
    required this.companyId,
    required this.companyName,
    required this.userId,
    required this.userName,
    required this.permissions,
    required CommandCenterRepository repository,
  }) : _repository = repository;

  final String companyId;
  final String companyName;
  final String userId;
  final String userName;
  final CommandCenterPermissions permissions;
  final CommandCenterRepository _repository;
  final _assistant = const ComplianceNaturalLanguageService();

  CommandCenterFilter filter = const CommandCenterFilter();
  CommandCenterMetrics metrics = const CommandCenterMetrics();
  AssistantAnswer? assistantAnswer;
  int selectedTab = 0;
  bool loading = false;
  String? error;
  Timer? _debounce;

  Stream<List<ComplianceRecord>> get compliance =>
      _repository.watchCompliance(companyId, filter);
  Stream<List<RiskRegisterItem>> get risks =>
      _repository.watchRisks(companyId, filter);
  Stream<List<GovernmentNotice>> get notices =>
      _repository.watchNotices(companyId, filter);
  Stream<List<LegalCase>> get cases =>
      _repository.watchCases(companyId, filter);
  Stream<List<PolicyDocument>> get policies =>
      _repository.watchPolicies(companyId, filter);
  Stream<List<AuditFinding>> get findings =>
      _repository.watchFindings(companyId, filter);
  Stream<List<ApprovalWorkflow>> get workflows =>
      _repository.watchWorkflows(companyId);
  Stream<List<Map<String, dynamic>>> get documents =>
      _repository.watchDocuments(companyId, filter);
  Stream<List<Map<String, dynamic>>> get audit =>
      _repository.watchAudit(companyId);
  Stream<List<SecurityControl>> get securityControls =>
      _repository.watchSecurityControls(companyId);

  Future<void> initialize() => refresh();

  Future<void> refresh() async {
    if (loading) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      metrics = await _repository.metrics(companyId, filter);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectTab(int value) {
    selectedTab = value;
    notifyListeners();
  }

  void setSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      filter = filter.copyWith(search: value);
      notifyListeners();
      refresh();
    });
  }

  void applyFilter(CommandCenterFilter value) {
    filter = value;
    notifyListeners();
    refresh();
  }

  void clearFilter() => applyFilter(filter.copyWith(clear: true));

  void ask(String query) {
    assistantAnswer = _assistant.interpret(query);
    if (assistantAnswer?.filter != null) {
      filter = assistantAnswer!.filter!;
    }
    if (assistantAnswer?.tab != null) {
      selectedTab = assistantAnswer!.tab!;
    }
    notifyListeners();
    refresh();
  }

  void _require(String action) {
    if (!permissions.can(action)) {
      throw StateError('You do not have permission to perform this action.');
    }
  }

  Future<void> saveRisk(RiskRegisterItem value) async {
    _require('edit');
    await _repository.saveRisk(value);
    await _audit('updated', 'risk_register', value.id);
    await refresh();
  }

  Future<void> saveWorkflow(ApprovalWorkflow value) async {
    _require('configure');
    await _repository.saveWorkflow(value);
    await _audit('updated', 'approval_workflow', value.id);
  }

  Future<void> saveNotice(GovernmentNotice value) async {
    _require('edit');
    await _repository.saveNotice(value);
    await _audit('updated', 'government_notices', value.id);
    await refresh();
  }

  Future<void> saveCase(LegalCase value) async {
    _require('edit');
    await _repository.saveCase(value);
    await _audit('updated', 'legal_cases', value.id);
    await refresh();
  }

  Future<void> savePolicy(PolicyDocument value) async {
    _require('edit');
    await _repository.savePolicy(value);
    await _audit('updated', 'policy_documents', value.id);
    await refresh();
  }

  Future<void> saveFinding(AuditFinding value) async {
    _require('edit');
    await _repository.saveFinding(value);
    await _audit('updated', 'audit_findings', value.id);
    await refresh();
  }

  Future<void> saveSecurityControl(SecurityControl value) async {
    _require('manageSecurity');
    await _repository.saveSecurityControl(value);
    await _audit('security_control_updated', 'security_controls', value.id);
  }

  Future<void> _audit(String action, String entityType, String entityId) =>
      _repository.writeAudit(
        companyId: companyId,
        userId: userId,
        userName: userName,
        action: action,
        entityType: entityType,
        entityId: entityId,
      );

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
