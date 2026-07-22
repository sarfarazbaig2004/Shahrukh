import '../models/income_tax_models.dart';

class TaxSlab {
  const TaxSlab({
    required this.fromInclusive,
    this.toInclusive,
    required this.rateBasisPoints,
  });

  final int fromInclusive;
  final int? toInclusive;
  final int rateBasisPoints;

  String get label {
    final from = fromInclusive == 0 ? '₹0' : '₹$fromInclusive';
    final to = toInclusive == null ? 'and above' : 'to ₹$toInclusive';
    return '$from $to';
  }
}

class TaxRuleSet {
  const TaxRuleSet({
    required this.financialYear,
    required this.oldRegimeSlabsBelow60,
    required this.oldRegimeSlabsSenior,
    required this.oldRegimeSlabsVerySenior,
    required this.newRegimeSlabs,
    required this.oldStandardDeduction,
    required this.newStandardDeduction,
    required this.oldRebateIncomeLimit,
    required this.oldRebateMaximum,
    required this.newRebateIncomeLimit,
    required this.newRebateMaximum,
    required this.cessBasisPoints,
    required this.section80CCombinedLimit,
    required this.section80CCD1BAdditionalLimit,
    required this.selfOccupiedHomeLoanInterestLimit,
    required this.stcg111ARateBasisPoints,
    required this.ltcg112ARateBasisPoints,
    required this.ltcg112AExemption,
    required this.otherLtcgRateBasisPoints,
    required this.lotteryRateBasisPoints,
    required this.sourceReference,
    required this.ruleVersion,
  });

  final FinancialYear financialYear;
  final List<TaxSlab> oldRegimeSlabsBelow60;
  final List<TaxSlab> oldRegimeSlabsSenior;
  final List<TaxSlab> oldRegimeSlabsVerySenior;
  final List<TaxSlab> newRegimeSlabs;
  final int oldStandardDeduction;
  final int newStandardDeduction;
  final int oldRebateIncomeLimit;
  final int oldRebateMaximum;
  final int newRebateIncomeLimit;
  final int newRebateMaximum;
  final int cessBasisPoints;
  final int section80CCombinedLimit;
  final int section80CCD1BAdditionalLimit;
  final int selfOccupiedHomeLoanInterestLimit;
  final int stcg111ARateBasisPoints;
  final int ltcg112ARateBasisPoints;
  final int ltcg112AExemption;
  final int otherLtcgRateBasisPoints;
  final int lotteryRateBasisPoints;
  final String sourceReference;
  final String ruleVersion;

  List<TaxSlab> slabsFor({
    required TaxRegime regime,
    required int age,
    required bool isResident,
  }) {
    if (regime == TaxRegime.newRegime) return newRegimeSlabs;
    if (!isResident) return oldRegimeSlabsBelow60;
    if (age >= 80) return oldRegimeSlabsVerySenior;
    if (age >= 60) return oldRegimeSlabsSenior;
    return oldRegimeSlabsBelow60;
  }

  int basicExemptionFor({
    required TaxRegime regime,
    required int age,
    required bool isResident,
  }) {
    final slabs = slabsFor(regime: regime, age: age, isResident: isResident);
    final nilSlab = slabs.firstWhere((slab) => slab.rateBasisPoints == 0);
    return nilSlab.toInclusive ?? 0;
  }
}
