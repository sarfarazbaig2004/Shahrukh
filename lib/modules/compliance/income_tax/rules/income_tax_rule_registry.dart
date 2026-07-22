import '../models/income_tax_models.dart';
import 'income_tax_rules.dart';

class IncomeTaxRuleRegistry {
  const IncomeTaxRuleRegistry();

  TaxRuleSet forYear(FinancialYear year) => switch (year) {
    FinancialYear.fy2025_26 => _fy2025_26,
    FinancialYear.fy2026_27 => _fy2026_27,
  };

  static const _oldBelow60 = <TaxSlab>[
    TaxSlab(fromInclusive: 0, toInclusive: 250000, rateBasisPoints: 0),
    TaxSlab(fromInclusive: 250001, toInclusive: 500000, rateBasisPoints: 500),
    TaxSlab(fromInclusive: 500001, toInclusive: 1000000, rateBasisPoints: 2000),
    TaxSlab(fromInclusive: 1000001, rateBasisPoints: 3000),
  ];

  static const _oldSenior = <TaxSlab>[
    TaxSlab(fromInclusive: 0, toInclusive: 300000, rateBasisPoints: 0),
    TaxSlab(fromInclusive: 300001, toInclusive: 500000, rateBasisPoints: 500),
    TaxSlab(fromInclusive: 500001, toInclusive: 1000000, rateBasisPoints: 2000),
    TaxSlab(fromInclusive: 1000001, rateBasisPoints: 3000),
  ];

  static const _oldVerySenior = <TaxSlab>[
    TaxSlab(fromInclusive: 0, toInclusive: 500000, rateBasisPoints: 0),
    TaxSlab(fromInclusive: 500001, toInclusive: 1000000, rateBasisPoints: 2000),
    TaxSlab(fromInclusive: 1000001, rateBasisPoints: 3000),
  ];

  static const _newSlabs = <TaxSlab>[
    TaxSlab(fromInclusive: 0, toInclusive: 400000, rateBasisPoints: 0),
    TaxSlab(fromInclusive: 400001, toInclusive: 800000, rateBasisPoints: 500),
    TaxSlab(fromInclusive: 800001, toInclusive: 1200000, rateBasisPoints: 1000),
    TaxSlab(
      fromInclusive: 1200001,
      toInclusive: 1600000,
      rateBasisPoints: 1500,
    ),
    TaxSlab(
      fromInclusive: 1600001,
      toInclusive: 2000000,
      rateBasisPoints: 2000,
    ),
    TaxSlab(
      fromInclusive: 2000001,
      toInclusive: 2400000,
      rateBasisPoints: 2500,
    ),
    TaxSlab(fromInclusive: 2400001, rateBasisPoints: 3000),
  ];

  static const _fy2025_26 = TaxRuleSet(
    financialYear: FinancialYear.fy2025_26,
    oldRegimeSlabsBelow60: _oldBelow60,
    oldRegimeSlabsSenior: _oldSenior,
    oldRegimeSlabsVerySenior: _oldVerySenior,
    newRegimeSlabs: _newSlabs,
    oldStandardDeduction: 50000,
    newStandardDeduction: 75000,
    oldRebateIncomeLimit: 500000,
    oldRebateMaximum: 12500,
    newRebateIncomeLimit: 1200000,
    newRebateMaximum: 60000,
    cessBasisPoints: 400,
    section80CCombinedLimit: 150000,
    section80CCD1BAdditionalLimit: 50000,
    selfOccupiedHomeLoanInterestLimit: 200000,
    stcg111ARateBasisPoints: 2000,
    ltcg112ARateBasisPoints: 1250,
    ltcg112AExemption: 125000,
    otherLtcgRateBasisPoints: 1250,
    lotteryRateBasisPoints: 3000,
    sourceReference: 'Finance Act 2025 / Income-tax Act 1961',
    ruleVersion: '2025.1',
  );

  static const _fy2026_27 = TaxRuleSet(
    financialYear: FinancialYear.fy2026_27,
    oldRegimeSlabsBelow60: _oldBelow60,
    oldRegimeSlabsSenior: _oldSenior,
    oldRegimeSlabsVerySenior: _oldVerySenior,
    newRegimeSlabs: _newSlabs,
    oldStandardDeduction: 50000,
    newStandardDeduction: 75000,
    oldRebateIncomeLimit: 500000,
    oldRebateMaximum: 12500,
    newRebateIncomeLimit: 1200000,
    newRebateMaximum: 60000,
    cessBasisPoints: 400,
    section80CCombinedLimit: 150000,
    section80CCD1BAdditionalLimit: 50000,
    selfOccupiedHomeLoanInterestLimit: 200000,
    stcg111ARateBasisPoints: 2000,
    ltcg112ARateBasisPoints: 1250,
    ltcg112AExemption: 125000,
    otherLtcgRateBasisPoints: 1250,
    lotteryRateBasisPoints: 3000,
    sourceReference: 'Income-tax Act 2025 / Finance Act 2026',
    ruleVersion: '2026.1',
  );
}
