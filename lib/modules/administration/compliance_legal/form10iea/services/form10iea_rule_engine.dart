import '../models/form10iea_models.dart';

class Form10IEARuleEngine {
  const Form10IEARuleEngine();

  Form10IEAResult evaluate({
    required Form10IEAAssessmentInput input,
    required List<Form10IEAScenarioRule> rules,
    required Form10IEAFinancialYearConfig yearConfig,
  }) {
    final missing = <String>[];

    if (input.proposedItr == null) {
      missing.add('Proposed ITR form');
    }

    for (final item in input.previousYears) {
      if (item.filed == null) {
        missing.add('${item.financialYear} filing status');
        continue;
      }

      if (item.filed == true) {
        if (item.confirmationStatus != Form10IEAConfirmationStatus.confirmed) {
          missing.add('${item.financialYear} confirmation');
        }

        if (item.selectedRegime.isEmpty) {
          missing.add('${item.financialYear} selected regime');
        }

        if (item.hasBusinessIncome == null) {
          missing.add(
            '${item.financialYear} business/professional income status',
          );
        }
      }
    }

    if (missing.isNotEmpty) {
      return Form10IEAResult(
        status: Form10IEAResultStatus.insufficientInformation,
        conclusion:
            'The information supplied is not sufficient for a reliable position.',
        formRequired: null,
        optionAvailable: null,
        reasons: const <String>[],
        missingInformation: missing,
        recommendedAction:
            'Complete and confirm every required field before analysis.',
        matchedRuleIds: const <String>[],
        legalReferences: const <String>[],
      );
    }

    final activeRules = rules.where((rule) {
      if (!rule.active) {
        return false;
      }

      if (rule.proposedItr != null && rule.proposedItr != input.proposedItr) {
        return false;
      }

      final latestFiled = input.previousYears.reversed.firstWhere(
        (item) => item.filed == true,
        orElse: () => input.previousYears.last,
      );

      if (rule.businessIncome != null &&
          rule.businessIncome != latestFiled.hasBusinessIncome) {
        return false;
      }

      if (rule.form10ieaFiled != null &&
          rule.form10ieaFiled != latestFiled.form10ieaFiled) {
        return false;
      }

      if (rule.previousRegime != 'Any' &&
          rule.previousRegime != latestFiled.selectedRegime) {
        return false;
      }

      if (rule.effectiveFrom.isNotEmpty &&
          yearConfig.targetFinancialYear.compareTo(rule.effectiveFrom) < 0) {
        return false;
      }

      if (rule.effectiveTo.isNotEmpty &&
          yearConfig.targetFinancialYear.compareTo(rule.effectiveTo) > 0) {
        return false;
      }

      return true;
    }).toList();

    if (activeRules.isEmpty) {
      return const Form10IEAResult(
        status: Form10IEAResultStatus.needsReview,
        conclusion:
            'No configured legal rule exactly matches the supplied information.',
        formRequired: null,
        optionAvailable: null,
        reasons: <String>[
          'The configured rule master has no exact active match.',
        ],
        missingInformation: <String>[],
        recommendedAction:
            'Verify the facts and obtain professional review before filing.',
        matchedRuleIds: <String>[],
        legalReferences: <String>[],
      );
    }

    final outcomes = activeRules.map((rule) => rule.resultStatus).toSet();

    if (outcomes.length > 1) {
      return Form10IEAResult(
        status: Form10IEAResultStatus.conflictingInformation,
        conclusion:
            'More than one configured rule matches with contradictory outcomes.',
        formRequired: null,
        optionAvailable: null,
        reasons: activeRules.map((rule) => 'Matched rule ${rule.id}').toList(),
        missingInformation: const <String>[],
        recommendedAction:
            'Review the matching rule versions before making a filing decision.',
        matchedRuleIds: activeRules.map((rule) => rule.id).toList(),
        legalReferences: activeRules
            .map((rule) => rule.legalReference)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(),
      );
    }

    if (activeRules.length > 1) {
      final versions = activeRules.map((rule) => rule.ruleVersion).toSet();

      if (versions.length > 1) {
        return Form10IEAResult(
          status: Form10IEAResultStatus.needsReview,
          conclusion: 'Multiple matching rule versions were found.',
          formRequired: null,
          optionAvailable: null,
          reasons: activeRules
              .map(
                (rule) =>
                    'Matched rule ${rule.id}, version ${rule.ruleVersion}',
              )
              .toList(),
          missingInformation: const <String>[],
          recommendedAction:
              'Ask an authorised rule manager to resolve duplicate active rules.',
          matchedRuleIds: activeRules.map((rule) => rule.id).toList(),
          legalReferences: activeRules
              .map((rule) => rule.legalReference)
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(),
        );
      }
    }

    final rule = activeRules.single;
    final status = rule.resultStatus;

    return Form10IEAResult(
      status: status,
      conclusion: _conclusion(status),
      formRequired: switch (status) {
        Form10IEAResultStatus.formRequired => true,
        Form10IEAResultStatus.formNotRequired => false,
        _ => null,
      },
      optionAvailable: switch (status) {
        Form10IEAResultStatus.optionAvailable => true,
        Form10IEAResultStatus.optionRestricted => false,
        _ => null,
      },
      reasons: <String>[
        'Matched active rule ${rule.id}.',
        if (rule.formRequirement.isNotEmpty) rule.formRequirement,
      ],
      missingInformation: const <String>[],
      recommendedAction:
          'Review the legal reference and confirm the filing position with an authorised tax professional.',
      matchedRuleIds: <String>[rule.id],
      legalReferences: rule.legalReference.isEmpty
          ? const <String>[]
          : <String>[rule.legalReference],
    );
  }

  String _conclusion(Form10IEAResultStatus status) {
    switch (status) {
      case Form10IEAResultStatus.formRequired:
        return 'The configured rule indicates that Form 10-IEA appears required.';
      case Form10IEAResultStatus.formNotRequired:
        return 'The configured rule indicates that Form 10-IEA does not appear required.';
      case Form10IEAResultStatus.optionAvailable:
        return 'The configured rule indicates that the requested regime option appears available.';
      case Form10IEAResultStatus.optionRestricted:
        return 'The configured rule indicates that the requested regime option appears restricted.';
      case Form10IEAResultStatus.insufficientInformation:
        return 'The information is insufficient.';
      case Form10IEAResultStatus.conflictingInformation:
        return 'The matching information is conflicting.';
      case Form10IEAResultStatus.needsReview:
        return 'Professional review is required.';
    }
  }
}
