import 'dart:typed_data';
import 'models.dart';

typedef CommandCenterFileHandler =
    Future<void> Function(String filename, Uint8List bytes, String mimeType);

abstract interface class CommandCenterDocumentService {
  Future<void> upload({
    required String companyId,
    required String userId,
    String? linkedRecordId,
  });
}

abstract interface class CommandCenterNotificationService {
  Future<void> send({
    required String companyId,
    required String channel,
    required List<String> recipients,
    required String subject,
    required String message,
  });
}

class AssistantAnswer {
  const AssistantAnswer({
    required this.title,
    required this.summary,
    this.tab,
    this.filter,
  });
  final String title;
  final String summary;
  final int? tab;
  final CommandCenterFilter? filter;
}

class ComplianceNaturalLanguageService {
  const ComplianceNaturalLanguageService();

  AssistantAnswer interpret(String query) {
    final q = query.trim().toLowerCase();
    if (q.contains('overdue') && q.contains('gst')) {
      return const AssistantAnswer(
        title: 'Overdue GST filings',
        summary: 'GST and overdue filters have been applied.',
        tab: 1,
        filter: CommandCenterFilter(search: 'GST', status: 'overdue'),
      );
    }
    if (q.contains('notice') && q.contains('income tax')) {
      return const AssistantAnswer(
        title: 'Income Tax notices',
        summary:
            'The notice register has been filtered for Income Tax Department.',
        tab: 5,
        filter: CommandCenterFilter(search: 'Income Tax'),
      );
    }
    if (q.contains('pending legal')) {
      return const AssistantAnswer(
        title: 'Pending legal cases',
        summary: 'Open legal matters are ready for review.',
        tab: 6,
      );
    }
    if (q.contains('risk mitigation')) {
      return const AssistantAnswer(
        title: 'Critical risk mitigation',
        summary:
            'Critical residual risks have been selected for control-owner and mitigation review.',
        tab: 2,
        filter: CommandCenterFilter(riskLevel: RiskLevel.critical),
      );
    }
    if (q.contains('audit')) {
      return const AssistantAnswer(
        title: 'Internal audit workspace',
        summary: 'Audit findings, CAPA and evidence are ready for review.',
        tab: 9,
      );
    }
    if (q.contains('194q')) {
      return const AssistantAnswer(
        title: 'Section 194Q',
        summary:
            'Open the maintained TDS/TCS Section Codes master for the approved enterprise interpretation and effective thresholds.',
      );
    }
    return const AssistantAnswer(
      title: 'Global compliance search',
      summary:
          'Your query has been applied to compliance, risk, notice, legal and policy records.',
    );
  }
}

class WorkflowEngine {
  const WorkflowEngine();

  WorkflowLevel? nextLevel(ApprovalWorkflow workflow, int currentOrder) {
    final levels = [...workflow.levels]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final level in levels) {
      if (level.order > currentOrder) return level;
    }
    return null;
  }

  DateTime reminderAt(WorkflowLevel level, DateTime assignedAt) =>
      assignedAt.add(Duration(hours: level.reminderHours));

  DateTime escalationAt(WorkflowLevel level, DateTime assignedAt) =>
      assignedAt.add(Duration(hours: level.escalationHours));
}
