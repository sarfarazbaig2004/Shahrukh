import 'package:flutter_test/flutter_test.dart';
import 'package:QUIK/modules/administration/compliance_legal/form10iea/models/form10iea_models.dart';
import 'package:QUIK/modules/administration/compliance_legal/form10iea/services/form10iea_rule_engine.dart';

void main() {
  const engine = Form10IEARuleEngine();

  Form10IEAAssessmentInput validInput({
    Form10IEAItrType proposedItr = Form10IEAItrType.itr3,
    bool businessIncome = true,
    bool formFiled = false,
    String regime = 'New Regime',
  }) {
    return Form10IEAAssessmentInput(
      temporaryId: 'test',
      proposedItr: proposedItr,
      previousYears: <PreviousYearFilingInput>[
        PreviousYearFilingInput(
          financialYear: 'FY 2023-24',
          assessmentYear: 'AY 2024-25',
          filed: false,
          confirmationStatus: Form10IEAConfirmationStatus.confirmed,
        ),
        PreviousYearFilingInput(
          financialYear: 'FY 2024-25',
          assessmentYear: 'AY 2025-26',
          filed: true,
          itrType: Form10IEAItrType.itr3,
          selectedRegime: regime,
          hasBusinessIncome: businessIncome,
          form10ieaFiled: formFiled,
          confirmationStatus: Form10IEAConfirmationStatus.confirmed,
        ),
      ],
    );
  }

  Form10IEAScenarioRule rule({
    required String id,
    required Form10IEAResultStatus result,
    String version = '1',
  }) {
    return Form10IEAScenarioRule(
      id: id,
      active: true,
      assesseType: 'Individual',
      previousRegime: 'New Regime',
      businessIncome: true,
      form10ieaFiled: false,
      proposedItr: Form10IEAItrType.itr3,
      resultStatus: result,
      formRequirement: 'Configured test rule',
      legalReference: 'Test reference',
      effectiveFrom: 'FY 2025-26',
      effectiveTo: '',
      ruleVersion: version,
      updatedBy: 'tester',
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  test('returns insufficient information for incomplete input', () {
    final result = engine.evaluate(
      input: Form10IEAAssessmentInput(
        temporaryId: 'empty',
        previousYears: const <PreviousYearFilingInput>[
          PreviousYearFilingInput(
            financialYear: 'FY 2023-24',
            assessmentYear: 'AY 2024-25',
          ),
          PreviousYearFilingInput(
            financialYear: 'FY 2024-25',
            assessmentYear: 'AY 2025-26',
          ),
        ],
      ),
      rules: const <Form10IEAScenarioRule>[],
      yearConfig: Form10IEAFinancialYearConfig.current,
    );

    expect(result.status, Form10IEAResultStatus.insufficientInformation);
  });

  test('returns needs review when no rule matches', () {
    final result = engine.evaluate(
      input: validInput(),
      rules: const <Form10IEAScenarioRule>[],
      yearConfig: Form10IEAFinancialYearConfig.current,
    );

    expect(result.status, Form10IEAResultStatus.needsReview);
  });

  test('returns one deterministic matching result', () {
    final result = engine.evaluate(
      input: validInput(),
      rules: <Form10IEAScenarioRule>[
        rule(id: 'RULE-1', result: Form10IEAResultStatus.formRequired),
      ],
      yearConfig: Form10IEAFinancialYearConfig.current,
    );

    expect(result.status, Form10IEAResultStatus.formRequired);
    expect(result.matchedRuleIds, <String>['RULE-1']);
  });

  test('returns conflicting information for contradictory rules', () {
    final result = engine.evaluate(
      input: validInput(),
      rules: <Form10IEAScenarioRule>[
        rule(id: 'RULE-1', result: Form10IEAResultStatus.formRequired),
        rule(id: 'RULE-2', result: Form10IEAResultStatus.formNotRequired),
      ],
      yearConfig: Form10IEAFinancialYearConfig.current,
    );

    expect(result.status, Form10IEAResultStatus.conflictingInformation);
  });

  test('different assessees keep independent temporary IDs', () {
    final first = validInput();
    final second = Form10IEAAssessmentInput(
      temporaryId: 'second',
      previousYears: first.previousYears,
      proposedItr: first.proposedItr,
    );

    expect(first.temporaryId, isNot(second.temporaryId));
  });

  test('safe map excludes raw PDF and full extracted text', () {
    final map = validInput().toSafeMap();

    expect(map.containsKey('rawPdf'), isFalse);
    expect(map.containsKey('pdfBytes'), isFalse);
    expect(map.containsKey('extractedText'), isFalse);
  });
}
