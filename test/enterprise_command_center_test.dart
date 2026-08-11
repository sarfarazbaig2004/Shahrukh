import 'package:flutter_test/flutter_test.dart';
import 'package:QUIK/modules/administration/compliance_legal/enterprise_command_center/enterprise_compliance_command_center.dart';

void main() {
  test('risk score maps to enterprise levels', () {
    expect(RiskRegisterItem.levelFor(1), RiskLevel.low);
    expect(RiskRegisterItem.levelFor(6), RiskLevel.medium);
    expect(RiskRegisterItem.levelFor(12), RiskLevel.high);
    expect(RiskRegisterItem.levelFor(20), RiskLevel.critical);
  });

  test('overall score applies overdue and critical risk penalty', () {
    const value = CommandCenterMetrics(
      totalCompliance: 100,
      completed: 90,
      overdue: 4,
      criticalRisks: 2,
    );
    expect(value.healthPercent, 90);
    expect(value.score, 76);
  });

  test('workflow engine returns the next level', () {
    final workflow = ApprovalWorkflow(
      id: 'w1',
      companyId: 'c1',
      name: 'Workflow',
      entityType: 'Compliance',
      createdBy: 'u1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      levels: [
        WorkflowLevel(
          id: '1',
          name: 'Manager',
          order: 1,
          approverRole: 'Manager',
        ),
        WorkflowLevel(id: '2', name: 'CFO', order: 2, approverRole: 'CFO'),
      ],
    );
    expect(const WorkflowEngine().nextLevel(workflow, 0)?.name, 'Manager');
    expect(const WorkflowEngine().nextLevel(workflow, 1)?.name, 'CFO');
  });

  test('assistant understands overdue GST request', () {
    final answer = const ComplianceNaturalLanguageService().interpret(
      'Show overdue GST filings',
    );
    expect(answer.tab, 1);
    expect(answer.filter?.status, 'overdue');
    expect(answer.filter?.search, 'GST');
  });

  test('legacy record without isDeleted remains active', () {
    final value = ComplianceRecord.fromMap('1', {
      'referenceNumber': 'CMP-1',
      'title': 'GST',
      'companyId': 'c1',
      'financialYear': 'FY 2026-27',
      'department': 'Finance',
      'ownerId': 'u1',
      'ownerName': 'Owner',
      'status': 'pending',
      'riskLevel': 'medium',
      'dueDate': DateTime(2026, 7, 31),
      'createdAt': DateTime(2026),
      'updatedAt': DateTime(2026),
    });
    expect(value.isDeleted, false);
  });
}
