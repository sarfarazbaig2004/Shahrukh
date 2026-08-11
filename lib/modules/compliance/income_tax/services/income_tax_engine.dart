import '../models/income_tax_models.dart';
import '../rules/income_tax_rule_registry.dart';
import '../rules/income_tax_rules.dart';

class IncomeTaxEngine {
  const IncomeTaxEngine({this.registry = const IncomeTaxRuleRegistry()});

  final IncomeTaxRuleRegistry registry;

  RegimeComparison compare(IncomeTaxDraft draft) {
    final oldResult = compute(draft, TaxRegime.oldRegime);
    final newResult = compute(draft, TaxRegime.newRegime);
    final recommended = oldResult.netTax <= newResult.netTax
        ? TaxRegime.oldRegime
        : TaxRegime.newRegime;
    final saving = (oldResult.netTax - newResult.netTax).abs();
    final higherTax = _max(oldResult.netTax, newResult.netTax);
    final savedBps = higherTax == 0 ? 0 : (saving * 10000) ~/ higherTax;

    return RegimeComparison(
      oldRegime: oldResult,
      newRegime: newResult,
      recommendedRegime: recommended,
      taxSaving: saving,
      percentageSavedBasisPoints: savedBps,
      suggestedItr: suggestItr(draft),
      planningSuggestions: buildPlanningSuggestions(
        draft: draft,
        oldResult: oldResult,
        newResult: newResult,
      ),
    );
  }

  TaxComputationResult compute(IncomeTaxDraft draft, TaxRegime regime) {
    final rules = registry.forYear(draft.financialYear);
    final profile = draft.profile;
    final income = draft.income;
    final yearEnd = _financialYearEnd(draft.financialYear);
    final age = profile.ageOn(yearEnd);
    final warnings = <String>[];

    if (!_supportsRegimeComparison(profile.category)) {
      warnings.add(
        'Old versus new regime comparison is designed for Individual, HUF, AOP and BOI. '
        'Firm, LLP, company and trust calculations require entity-specific options and audit review.',
      );
    }

    if (profile.category == TaxpayerCategory.aop ||
        profile.category == TaxpayerCategory.boi) {
      warnings.add(
        'AOP/BOI member-rate, maximum-marginal-rate and share-determination rules are not inferred automatically. Final liability requires member-level validation.',
      );
    }

    final salary = _max(0, income.grossSalary - income.salaryExemptions);
    final standardDeduction = salary > 0
        ? (regime == TaxRegime.newRegime
              ? rules.newStandardDeduction
              : rules.oldStandardDeduction)
        : 0;
    final professionalTaxDeduction = regime == TaxRegime.oldRegime
        ? _min(income.professionalTax, salary)
        : 0;
    final salaryDeductions = _min(
      salary,
      standardDeduction + professionalTaxDeduction,
    );
    final taxableSalary = _max(0, salary - salaryDeductions);

    final housePropertyIncome = _housePropertyIncome(
      income: income,
      rules: rules,
      regime: regime,
      warnings: warnings,
    );

    final grossBeforeChapterVIA =
        taxableSalary +
        housePropertyIncome +
        income.businessProfessionIncome +
        income.stcgOther +
        income.interestIncome +
        income.dividendIncome +
        income.giftsIncome +
        income.foreignIncome +
        income.stcg111A +
        income.ltcg112A +
        income.ltcgOther +
        income.lotteryIncome;

    final grossIncome = _max(0, grossBeforeChapterVIA);
    final chapterVIA = _chapterVIADeduction(
      draft: draft,
      regime: regime,
      rules: rules,
      grossBeforeChapterVIA: grossIncome,
      age: age,
      warnings: warnings,
    );

    final taxableBeforeSpecialSplit = _max(0, grossIncome - chapterVIA);
    final declaredSpecialIncome =
        income.stcg111A +
        income.ltcg112A +
        income.ltcgOther +
        income.lotteryIncome;
    final specialIncome = _min(
      taxableBeforeSpecialSplit,
      declaredSpecialIncome,
    );
    var normalIncome = _max(0, taxableBeforeSpecialSplit - specialIncome);

    final slabs = _slabsForCategory(
      profile: profile,
      rules: rules,
      regime: regime,
      age: age,
      warnings: warnings,
    );
    final basicExemption =
        slabs
            .firstWhere(
              (slab) => slab.rateBasisPoints == 0,
              orElse: () => const TaxSlab(
                fromInclusive: 0,
                toInclusive: 0,
                rateBasisPoints: 0,
              ),
            )
            .toInclusive ??
        0;

    var stcg111ATaxable = income.stcg111A;
    var ltcg112ATaxable = _max(0, income.ltcg112A - rules.ltcg112AExemption);
    var ltcgOtherTaxable = income.ltcgOther;
    final lotteryTaxable = income.lotteryIncome;

    if (_isIndividualLike(profile.category) && profile.isResident) {
      var unusedBasicExemption = _max(0, basicExemption - normalIncome);
      final stcgAdjustment = _min(unusedBasicExemption, stcg111ATaxable);
      stcg111ATaxable -= stcgAdjustment;
      unusedBasicExemption -= stcgAdjustment;

      final ltcg112AAdjustment = _min(unusedBasicExemption, ltcg112ATaxable);
      ltcg112ATaxable -= ltcg112AAdjustment;
      unusedBasicExemption -= ltcg112AAdjustment;

      final otherLtcgAdjustment = _min(unusedBasicExemption, ltcgOtherTaxable);
      ltcgOtherTaxable -= otherLtcgAdjustment;
    }

    final slabResult = _calculateSlabTax(
      taxableIncome: normalIncome,
      slabs: slabs,
      agriculturalIncome: income.agriculturalIncome,
      basicExemption: basicExemption,
      applyAgriculturalIntegration:
          _isIndividualLike(profile.category) && profile.isResident,
    );

    final stcg111ATax = _percentage(
      stcg111ATaxable,
      rules.stcg111ARateBasisPoints,
    );
    final ltcg112ATax = _percentage(
      ltcg112ATaxable,
      rules.ltcg112ARateBasisPoints,
    );
    final ltcgOtherTax = _percentage(
      ltcgOtherTaxable,
      rules.otherLtcgRateBasisPoints,
    );
    final lotteryTax = _percentage(
      lotteryTaxable,
      rules.lotteryRateBasisPoints,
    );
    final specialRateTax =
        stcg111ATax + ltcg112ATax + ltcgOtherTax + lotteryTax;

    var rebate = 0;
    if (profile.category == TaxpayerCategory.individual && profile.isResident) {
      if (regime == TaxRegime.oldRegime &&
          taxableBeforeSpecialSplit <= rules.oldRebateIncomeLimit) {
        rebate = _min(rules.oldRebateMaximum, slabResult.tax);
      }
      if (regime == TaxRegime.newRegime &&
          taxableBeforeSpecialSplit <= rules.newRebateIncomeLimit) {
        rebate = _min(rules.newRebateMaximum, slabResult.tax);
      } else if (regime == TaxRegime.newRegime &&
          taxableBeforeSpecialSplit > rules.newRebateIncomeLimit &&
          specialRateTax == 0) {
        final taxAfterRegularRebate = slabResult.tax;
        final excessIncome =
            taxableBeforeSpecialSplit - rules.newRebateIncomeLimit;
        if (taxAfterRegularRebate > excessIncome) {
          rebate = taxAfterRegularRebate - excessIncome;
        }
      }
    }

    final normalTaxAfterRebate = _max(0, slabResult.tax - rebate);
    final baseTax = normalTaxAfterRebate + specialRateTax;
    final surchargeResult = _calculateSurcharge(
      category: profile.category,
      regime: regime,
      totalIncome: taxableBeforeSpecialSplit,
      normalAndLotteryTax: normalTaxAfterRebate + lotteryTax,
      cappedSpecialTax: stcg111ATax + ltcg112ATax + ltcgOtherTax,
      warnings: warnings,
    );

    final taxAndSurcharge = baseTax + surchargeResult.surcharge;
    final cess = _percentage(taxAndSurcharge, rules.cessBasisPoints);
    final taxBeforeInterest = taxAndSurcharge + cess;

    final advanceTaxSchedule = _advanceTaxSchedule(
      taxBeforeInterest: taxBeforeInterest,
      draft: draft,
    );
    final interest234C = _interest234C(
      schedule: advanceTaxSchedule,
      payments: draft.payments,
      exemptFromAdvanceTax: _isExemptFromAdvanceTax(draft, age),
    );
    final interest234A = _interest234A(
      taxBeforeInterest: taxBeforeInterest,
      payments: draft.payments,
    );
    final interest234B = _interest234B(
      taxBeforeInterest: taxBeforeInterest,
      financialYear: draft.financialYear,
      payments: draft.payments,
      exemptFromAdvanceTax: _isExemptFromAdvanceTax(draft, age),
    );

    final penalty = 0;
    final netTax =
        taxBeforeInterest +
        interest234A +
        interest234B +
        interest234C +
        penalty;
    final paid = draft.payments.totalTaxesPaid;
    final payable = _max(0, netTax - paid);
    final refund = _max(0, paid - netTax);

    if (income.foreignIncome > 0) {
      warnings.add(
        'Foreign tax credit, DTAA relief and Schedule FSI/TR are not automatically computed.',
      );
    }
    if (income.ltcgOther > 0) {
      warnings.add(
        'Other LTCG may require asset-date, indexation and grandfathering choices. Review before filing.',
      );
    }
    if (taxableBeforeSpecialSplit > 5000000) {
      warnings.add(
        'Surcharge is calculated with statutory rate caps. Confirm marginal relief and income allocation during final review.',
      );
    }

    return TaxComputationResult(
      regime: regime,
      grossIncome: grossIncome,
      salaryDeductions: salaryDeductions,
      chapterVIADeductions: chapterVIA,
      totalDeductions: salaryDeductions + chapterVIA,
      taxableIncome: taxableBeforeSpecialSplit,
      normalIncome: normalIncome,
      specialRateIncome: specialIncome,
      slabTax: slabResult.tax,
      specialRateTax: specialRateTax,
      surcharge: surchargeResult.surcharge,
      marginalRelief: surchargeResult.marginalRelief,
      rebate: rebate,
      cess: cess,
      interest234A: interest234A,
      interest234B: interest234B,
      interest234C: interest234C,
      penalty: penalty,
      netTax: netTax,
      totalPaid: paid,
      payable: payable,
      refund: refund,
      slabLines: slabResult.lines,
      advanceTaxSchedule: advanceTaxSchedule,
      warnings: List.unmodifiable(warnings.toSet()),
    );
  }

  String suggestItr(IncomeTaxDraft draft) {
    final category = draft.profile.category;
    final income = draft.income;
    final totalIncome = _simpleTotalIncome(draft);
    final ordinaryResident =
        draft.profile.residentialStatus == ResidentialStatus.resident;
    final simpleSection112A =
        income.ltcg112A <= 125000 &&
        income.stcg111A == 0 &&
        income.stcgOther == 0 &&
        income.ltcgOther == 0;
    final simpleSources =
        income.foreignIncome == 0 &&
        income.agriculturalIncome <= 5000 &&
        simpleSection112A;
    final presumptiveOnly =
        income.presumptiveIncome > 0 &&
        income.businessIncome == 0 &&
        income.professionalIncome == 0;
    final mayUseItr4 =
        ordinaryResident &&
        presumptiveOnly &&
        totalIncome <= 5000000 &&
        simpleSources;

    return switch (category) {
      TaxpayerCategory.company => 'ITR-6',
      TaxpayerCategory.trust => 'ITR-7',
      TaxpayerCategory.llp ||
      TaxpayerCategory.aop ||
      TaxpayerCategory.boi => 'ITR-5',
      TaxpayerCategory.firm => mayUseItr4 ? 'ITR-4' : 'ITR-5',
      TaxpayerCategory.huf =>
        income.hasBusinessOrProfession
            ? (mayUseItr4 ? 'ITR-4' : 'ITR-3')
            : 'ITR-2',
      TaxpayerCategory.individual =>
        income.hasBusinessOrProfession
            ? (mayUseItr4 ? 'ITR-4' : 'ITR-3')
            : (ordinaryResident && totalIncome <= 5000000 && simpleSources
                  ? 'ITR-1'
                  : 'ITR-2'),
    };
  }

  List<String> buildPlanningSuggestions({
    required IncomeTaxDraft draft,
    required TaxComputationResult oldResult,
    required TaxComputationResult newResult,
  }) {
    final rules = registry.forYear(draft.financialYear);
    final suggestions = <String>[];
    final used80C = _min(
      rules.section80CCombinedLimit,
      draft.deductions.declared80C +
          draft.deductions.section80CCC +
          draft.deductions.section80CCD1,
    );
    final additional80C = _max(0, rules.section80CCombinedLimit - used80C);
    final usedNps = _min(
      rules.section80CCD1BAdditionalLimit,
      _max(draft.deductions.section80CCD1B, draft.deductions.nps),
    );
    final additionalNps = _max(
      0,
      rules.section80CCD1BAdditionalLimit - usedNps,
    );

    if (oldResult.netTax < newResult.netTax && additional80C > 0) {
      suggestions.add(
        'Additional eligible 80C investment available: ₹$additional80C.',
      );
    }
    if (oldResult.netTax < newResult.netTax && additionalNps > 0) {
      suggestions.add(
        'Additional NPS deduction opportunity under 80CCD(1B): ₹$additionalNps.',
      );
    }
    if (draft.deductions.section80D == 0 &&
        draft.profile.category == TaxpayerCategory.individual) {
      suggestions.add(
        'Review eligible health-insurance premium under section 80D.',
      );
    }
    if (draft.deductions.section80G == 0) {
      suggestions.add(
        'Eligible donations may qualify under section 80G; retain approved receipts.',
      );
    }
    if (draft.income.hasBusinessOrProfession) {
      suggestions.add(
        'Confirm the applicable regime-option form and statutory filing deadline before finalising business or professional income.',
      );
    }
    final recommended = oldResult.netTax <= newResult.netTax ? 'Old' : 'New';
    suggestions.add(
      '$recommended Regime currently produces the lower computed liability.',
    );
    return suggestions;
  }

  int _chapterVIADeduction({
    required IncomeTaxDraft draft,
    required TaxRegime regime,
    required TaxRuleSet rules,
    required int grossBeforeChapterVIA,
    required int age,
    required List<String> warnings,
  }) {
    final d = draft.deductions;
    if (regime == TaxRegime.newRegime) {
      final allowed = d.section80CCD2;
      if (_sumOldRegimeOnlyDeductions(d) > 0) {
        warnings.add(
          'Most Chapter VI-A deductions entered are not allowed in the default new regime; only configured eligible deductions were applied.',
        );
      }
      return _min(grossBeforeChapterVIA, allowed);
    }

    final combined80C = _min(
      rules.section80CCombinedLimit,
      d.declared80C + d.section80CCC + d.section80CCD1,
    );
    final additionalNps = _min(
      rules.section80CCD1BAdditionalLimit,
      _max(d.section80CCD1B, d.nps),
    );
    final interestDeduction = age >= 60
        ? _min(d.section80TTB, 50000)
        : _min(d.section80TTA, 10000);

    final total =
        combined80C +
        additionalNps +
        d.section80CCD2 +
        d.section80D +
        d.section80DD +
        d.section80DDB +
        d.section80E +
        d.section80EE +
        d.section80EEA +
        d.section80EEB +
        d.section80G +
        d.section80GG +
        d.section80GGA +
        d.section80GGC +
        interestDeduction +
        d.section80U;
    return _min(grossBeforeChapterVIA, total);
  }

  int _sumOldRegimeOnlyDeductions(DeductionInputs d) =>
      d.declared80C +
      d.section80CCC +
      d.section80CCD1 +
      d.section80CCD1B +
      d.section80D +
      d.section80DD +
      d.section80DDB +
      d.section80E +
      d.section80EE +
      d.section80EEA +
      d.section80EEB +
      d.section80G +
      d.section80GG +
      d.section80GGA +
      d.section80GGC +
      d.section80TTA +
      d.section80TTB +
      d.section80U;

  int _housePropertyIncome({
    required IncomeInputs income,
    required TaxRuleSet rules,
    required TaxRegime regime,
    required List<String> warnings,
  }) {
    if (income.isSelfOccupied) {
      if (regime == TaxRegime.newRegime && income.homeLoanInterest > 0) {
        warnings.add(
          'Self-occupied home-loan interest was not deducted under the new regime.',
        );
        return 0;
      }
      return -_min(
        income.homeLoanInterest,
        rules.selfOccupiedHomeLoanInterestLimit,
      );
    }

    final netAnnualValue = _max(
      0,
      income.housePropertyAnnualValue - income.municipalTax,
    );
    final standardDeduction = _percentage(netAnnualValue, 3000);
    final result = netAnnualValue - standardDeduction - income.homeLoanInterest;
    if (regime == TaxRegime.newRegime && result < 0) {
      warnings.add(
        'Loss from let-out property is restricted to zero for cross-head set-off in this calculator under the new regime.',
      );
      return 0;
    }
    if (regime == TaxRegime.oldRegime && result < -200000) {
      warnings.add(
        'Current-year house-property loss set off against other heads was capped at ₹2,00,000. Carry-forward loss requires a return-level schedule.',
      );
      return -200000;
    }
    return result;
  }

  List<TaxSlab> _slabsForCategory({
    required TaxpayerProfile profile,
    required TaxRuleSet rules,
    required TaxRegime regime,
    required int age,
    required List<String> warnings,
  }) {
    if (_isIndividualLike(profile.category)) {
      if (profile.category == TaxpayerCategory.individual) {
        return rules.slabsFor(
          regime: regime,
          age: age,
          isResident: profile.isResident,
        );
      }
      return rules.slabsFor(regime: regime, age: 0, isResident: false);
    }

    warnings.add(
      'Entity categories are shown using a 30% flat base rate. Configure turnover/concessional-section options before production filing.',
    );
    return const <TaxSlab>[TaxSlab(fromInclusive: 0, rateBasisPoints: 3000)];
  }

  _SlabResult _calculateSlabTax({
    required int taxableIncome,
    required List<TaxSlab> slabs,
    required int agriculturalIncome,
    required int basicExemption,
    required bool applyAgriculturalIntegration,
  }) {
    if (applyAgriculturalIntegration &&
        agriculturalIncome > 5000 &&
        taxableIncome > basicExemption) {
      final taxOnCombined = _calculateSlabTax(
        taxableIncome: taxableIncome + agriculturalIncome,
        slabs: slabs,
        agriculturalIncome: 0,
        basicExemption: basicExemption,
        applyAgriculturalIntegration: false,
      ).tax;
      final taxOnAgriculturalBase = _calculateSlabTax(
        taxableIncome: agriculturalIncome + basicExemption,
        slabs: slabs,
        agriculturalIncome: 0,
        basicExemption: basicExemption,
        applyAgriculturalIntegration: false,
      ).tax;
      return _SlabResult(
        tax: _max(0, taxOnCombined - taxOnAgriculturalBase),
        lines: _slabLines(taxableIncome, slabs),
      );
    }

    final lines = _slabLines(taxableIncome, slabs);
    return _SlabResult(
      tax: lines.fold<int>(0, (sum, line) => sum + line.tax),
      lines: lines,
    );
  }

  List<SlabTaxLine> _slabLines(int taxableIncome, List<TaxSlab> slabs) {
    final result = <SlabTaxLine>[];
    for (final slab in slabs) {
      final lower = slab.fromInclusive == 0 ? 0 : slab.fromInclusive - 1;
      if (taxableIncome <= lower) continue;
      final upper = slab.toInclusive ?? taxableIncome;
      final taxableInSlab = _max(0, _min(taxableIncome, upper) - lower);
      if (taxableInSlab == 0) continue;
      result.add(
        SlabTaxLine(
          label: slab.label,
          taxableAmount: taxableInSlab,
          rateBasisPoints: slab.rateBasisPoints,
          tax: _percentage(taxableInSlab, slab.rateBasisPoints),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  _SurchargeResult _calculateSurcharge({
    required TaxpayerCategory category,
    required TaxRegime regime,
    required int totalIncome,
    required int normalAndLotteryTax,
    required int cappedSpecialTax,
    required List<String> warnings,
  }) {
    if (category == TaxpayerCategory.firm || category == TaxpayerCategory.llp) {
      if (totalIncome <= 10000000) {
        return const _SurchargeResult(surcharge: 0, marginalRelief: 0);
      }
      final raw = _percentage(normalAndLotteryTax + cappedSpecialTax, 1200);
      final maximumIncrease = totalIncome - 10000000;
      final thresholdTax = _percentage(10000000, 3000);
      final currentTax = normalAndLotteryTax + cappedSpecialTax + raw;
      final relief = _max(0, currentTax - (thresholdTax + maximumIncrease));
      return _SurchargeResult(
        surcharge: _max(0, raw - relief),
        marginalRelief: relief,
      );
    }

    if (!_isIndividualLike(category)) {
      return const _SurchargeResult(surcharge: 0, marginalRelief: 0);
    }

    final generalRate = switch (totalIncome) {
      > 50000000 => regime == TaxRegime.newRegime ? 2500 : 3700,
      > 20000000 => 2500,
      > 10000000 => 1500,
      > 5000000 => 1000,
      _ => 0,
    };
    final cappedRate = _min(generalRate, 1500);
    final raw =
        _percentage(normalAndLotteryTax, generalRate) +
        _percentage(cappedSpecialTax, cappedRate);

    if (raw == 0) {
      return const _SurchargeResult(surcharge: 0, marginalRelief: 0);
    }

    final threshold = switch (totalIncome) {
      > 50000000 => 50000000,
      > 20000000 => 20000000,
      > 10000000 => 10000000,
      > 5000000 => 5000000,
      _ => 0,
    };
    final baseTax = normalAndLotteryTax + cappedSpecialTax;
    final effectiveBaseAtThreshold = totalIncome == 0
        ? 0
        : (baseTax * threshold) ~/ totalIncome;
    final priorRate = switch (threshold) {
      50000000 => 2500,
      20000000 => 1500,
      10000000 => 1000,
      5000000 => 0,
      _ => 0,
    };
    final thresholdTaxWithSurcharge =
        effectiveBaseAtThreshold +
        _percentage(effectiveBaseAtThreshold, priorRate);
    final allowed = thresholdTaxWithSurcharge + (totalIncome - threshold);
    final current = baseTax + raw;
    final relief = _max(0, current - allowed);

    if (relief > 0) {
      warnings.add(
        'Marginal relief was applied using the configured surcharge thresholds.',
      );
    }
    return _SurchargeResult(
      surcharge: _max(0, raw - relief),
      marginalRelief: relief,
    );
  }

  AdvanceTaxSchedule _advanceTaxSchedule({
    required int taxBeforeInterest,
    required IncomeTaxDraft draft,
  }) {
    final assessedTax = _max(0, taxBeforeInterest - draft.payments.tdsTcs);
    if (assessedTax < 10000) {
      return const AdvanceTaxSchedule(
        june15: 0,
        september15: 0,
        december15: 0,
        march15: 0,
      );
    }
    if (draft.income.presumptiveIncome > 0 &&
        draft.income.businessIncome == 0 &&
        draft.income.professionalIncome == 0) {
      return AdvanceTaxSchedule(
        june15: 0,
        september15: 0,
        december15: 0,
        march15: assessedTax,
      );
    }
    return AdvanceTaxSchedule(
      june15: _percentage(assessedTax, 1500),
      september15: _percentage(assessedTax, 4500),
      december15: _percentage(assessedTax, 7500),
      march15: assessedTax,
    );
  }

  int _interest234C({
    required AdvanceTaxSchedule schedule,
    required TaxPaymentInputs payments,
    required bool exemptFromAdvanceTax,
  }) {
    if (exemptFromAdvanceTax) return 0;
    var interest = 0;
    final juneShortfall = _max(0, schedule.june15 - payments.advanceTaxJune);
    interest += _percentage(juneShortfall, 100) * 3;

    final septemberPaid =
        payments.advanceTaxJune + payments.advanceTaxSeptember;
    final septemberShortfall = _max(0, schedule.september15 - septemberPaid);
    interest += _percentage(septemberShortfall, 100) * 3;

    final decemberPaid = septemberPaid + payments.advanceTaxDecember;
    final decemberShortfall = _max(0, schedule.december15 - decemberPaid);
    interest += _percentage(decemberShortfall, 100) * 3;

    final marchPaid = decemberPaid + payments.advanceTaxMarch;
    final marchShortfall = _max(0, schedule.march15 - marchPaid);
    interest += _percentage(marchShortfall, 100);
    return interest;
  }

  int _interest234A({
    required int taxBeforeInterest,
    required TaxPaymentInputs payments,
  }) {
    final due = payments.returnDueDate;
    final filed = payments.returnFilingDate;
    if (due == null || filed == null || !filed.isAfter(due)) return 0;
    final unpaid = _max(
      0,
      taxBeforeInterest - payments.tdsTcs - payments.advanceTaxPaid,
    );
    return _percentage(unpaid, 100) * _monthsOrPart(due, filed);
  }

  int _interest234B({
    required int taxBeforeInterest,
    required FinancialYear financialYear,
    required TaxPaymentInputs payments,
    required bool exemptFromAdvanceTax,
  }) {
    if (exemptFromAdvanceTax) return 0;
    final assessedTax = _max(0, taxBeforeInterest - payments.tdsTcs);
    if (assessedTax < 10000 ||
        payments.advanceTaxPaid * 100 >= assessedTax * 90) {
      return 0;
    }
    final start = switch (financialYear) {
      FinancialYear.fy2025_26 => DateTime(2026, 4, 1),
      FinancialYear.fy2026_27 => DateTime(2027, 4, 1),
    };
    final end =
        payments.selfAssessmentPaymentDate ??
        payments.returnFilingDate ??
        start;
    if (!end.isAfter(start)) return 0;
    final shortfall = _max(0, assessedTax - payments.advanceTaxPaid);
    return _percentage(shortfall, 100) * _monthsOrPart(start, end);
  }

  bool _isExemptFromAdvanceTax(IncomeTaxDraft draft, int age) =>
      draft.profile.category == TaxpayerCategory.individual &&
      draft.profile.isResident &&
      age >= 60 &&
      !draft.income.hasBusinessOrProfession;

  int _monthsOrPart(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return 0;
    var months = (end.year - start.year) * 12 + end.month - start.month;
    if (end.day > start.day || months == 0) months++;
    return _max(1, months);
  }

  DateTime _financialYearEnd(FinancialYear year) => switch (year) {
    FinancialYear.fy2025_26 => DateTime(2026, 3, 31),
    FinancialYear.fy2026_27 => DateTime(2027, 3, 31),
  };

  int _simpleTotalIncome(IncomeTaxDraft draft) =>
      draft.income.grossSalary +
      draft.income.housePropertyAnnualValue +
      draft.income.businessProfessionIncome +
      draft.income.capitalGains +
      draft.income.otherSources;

  bool _supportsRegimeComparison(TaxpayerCategory category) =>
      category == TaxpayerCategory.individual ||
      category == TaxpayerCategory.huf ||
      category == TaxpayerCategory.aop ||
      category == TaxpayerCategory.boi;

  bool _isIndividualLike(TaxpayerCategory category) =>
      category == TaxpayerCategory.individual ||
      category == TaxpayerCategory.huf ||
      category == TaxpayerCategory.aop ||
      category == TaxpayerCategory.boi;

  int _min(int a, int b) => a < b ? a : b;
  int _max(int a, int b) => a > b ? a : b;

  int _percentage(int amount, int basisPoints) {
    if (amount <= 0 || basisPoints <= 0) return 0;
    return (amount * basisPoints + 5000) ~/ 10000;
  }
}

class _SlabResult {
  const _SlabResult({required this.tax, required this.lines});
  final int tax;
  final List<SlabTaxLine> lines;
}

class _SurchargeResult {
  const _SurchargeResult({
    required this.surcharge,
    required this.marginalRelief,
  });

  final int surcharge;
  final int marginalRelief;
}
