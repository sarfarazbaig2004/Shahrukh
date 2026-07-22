import 'package:flutter_test/flutter_test.dart';
import '../lib/modules/compliance/income_tax/models/income_tax_models.dart';
import '../lib/modules/compliance/income_tax/services/income_tax_engine.dart';

void main() {
  const engine = IncomeTaxEngine();

  group('IncomeTaxEngine FY 2025-26', () {
    test('new regime gives nil tax at salaried gross income of 12.75 lakh', () {
      const draft = IncomeTaxDraft(
        financialYear: FinancialYear.fy2025_26,
        profile: TaxpayerProfile(
          residentialStatus: ResidentialStatus.resident,
          category: TaxpayerCategory.individual,
        ),
        income: IncomeInputs(basicSalary: 1275000),
      );

      final result = engine.compute(draft, TaxRegime.newRegime);

      expect(result.taxableIncome, 1200000);
      expect(result.slabTax, 60000);
      expect(result.rebate, 60000);
      expect(result.netTax, 0);
    });

    test(
      'new regime computes final payable including 234C interest on salary of 15 lakh',
      () {
        const draft = IncomeTaxDraft(
          financialYear: FinancialYear.fy2025_26,
          profile: TaxpayerProfile(
            residentialStatus: ResidentialStatus.resident,
            category: TaxpayerCategory.individual,
          ),
          income: IncomeInputs(basicSalary: 1500000),
        );

        final result = engine.compute(draft, TaxRegime.newRegime);

        expect(result.taxableIncome, 1425000);
        expect(result.slabTax, 93750);
        expect(result.cess, 3750);
        expect(result.netTax, 102423);
      },
    );

    test('old regime applies standard deduction and combined 80C cap', () {
      const draft = IncomeTaxDraft(
        financialYear: FinancialYear.fy2025_26,
        profile: TaxpayerProfile(
          residentialStatus: ResidentialStatus.resident,
          category: TaxpayerCategory.individual,
        ),
        income: IncomeInputs(basicSalary: 1000000),
        deductions: DeductionInputs(section80CManual: 150000),
      );

      final result = engine.compute(draft, TaxRegime.oldRegime);

      expect(result.taxableIncome, 800000);
      expect(result.slabTax, 72500);
      expect(result.cess, 2900);
      expect(result.netTax, 79208);
    });

    test('special-rate LTCG 112A exemption is applied', () {
      const draft = IncomeTaxDraft(
        financialYear: FinancialYear.fy2025_26,
        profile: TaxpayerProfile(
          residentialStatus: ResidentialStatus.resident,
          category: TaxpayerCategory.individual,
        ),
        income: IncomeInputs(ltcg112A: 225000),
      );

      final result = engine.compute(draft, TaxRegime.newRegime);

      expect(
        result.specialRateTax,
        0,
        reason: 'Unused basic exemption absorbs the taxable LTCG in this case.',
      );
    });

    test('comparison recommends lower liability', () {
      const draft = IncomeTaxDraft(
        financialYear: FinancialYear.fy2025_26,
        profile: TaxpayerProfile(
          residentialStatus: ResidentialStatus.resident,
          category: TaxpayerCategory.individual,
        ),
        income: IncomeInputs(basicSalary: 1500000),
      );

      final result = engine.compare(draft);

      expect(result.recommendedRegime, TaxRegime.newRegime);
      expect(result.taxSaving, greaterThan(0));
    });
  });

  test('FY 2026-27 uses Tax Year label and same configured new slabs', () {
    const draft = IncomeTaxDraft(
      financialYear: FinancialYear.fy2026_27,
      profile: TaxpayerProfile(
        residentialStatus: ResidentialStatus.resident,
        category: TaxpayerCategory.individual,
      ),
      income: IncomeInputs(basicSalary: 1275000),
    );

    final result = engine.compute(draft, TaxRegime.newRegime);

    expect(draft.financialYear.statutoryYearLabel, 'Tax Year 2026-27');
    expect(result.netTax, 0);
  });
}
