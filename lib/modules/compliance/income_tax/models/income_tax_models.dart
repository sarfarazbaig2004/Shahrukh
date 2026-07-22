import 'package:flutter/foundation.dart';

enum FinancialYear {
  fy2025_26,
  fy2026_27;

  String get label => switch (this) {
    FinancialYear.fy2025_26 => 'FY 2025-26',
    FinancialYear.fy2026_27 => 'FY 2026-27',
  };

  String get statutoryYearLabel => switch (this) {
    FinancialYear.fy2025_26 => 'AY 2026-27',
    FinancialYear.fy2026_27 => 'Tax Year 2026-27',
  };

  String get storageValue => name;

  static FinancialYear fromStorage(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => FinancialYear.fy2025_26,
  );
}

enum TaxRegime { oldRegime, newRegime }

enum ResidentialStatus { resident, rnOR, nonResident }

enum TaxpayerCategory { individual, huf, firm, llp, company, trust, aop, boi }

enum Gender { male, female, other, notApplicable }

enum CalculationStatus { draft, finalised }

@immutable
class TaxpayerProfile {
  const TaxpayerProfile({
    this.name = '',
    this.pan = '',
    this.aadhaar = '',
    this.dob,
    this.residentialStatus = ResidentialStatus.resident,
    this.category = TaxpayerCategory.individual,
    this.gender = Gender.notApplicable,
  });

  final String name;
  final String pan;
  final String aadhaar;
  final DateTime? dob;
  final ResidentialStatus residentialStatus;
  final TaxpayerCategory category;
  final Gender gender;

  int ageOn(DateTime date) {
    if (dob == null) return 0;
    var age = date.year - dob!.year;
    if (date.month < dob!.month ||
        (date.month == dob!.month && date.day < dob!.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  bool get isResident => residentialStatus == ResidentialStatus.resident;

  TaxpayerProfile copyWith({
    String? name,
    String? pan,
    String? aadhaar,
    DateTime? dob,
    bool clearDob = false,
    ResidentialStatus? residentialStatus,
    TaxpayerCategory? category,
    Gender? gender,
  }) {
    return TaxpayerProfile(
      name: name ?? this.name,
      pan: pan ?? this.pan,
      aadhaar: aadhaar ?? this.aadhaar,
      dob: clearDob ? null : (dob ?? this.dob),
      residentialStatus: residentialStatus ?? this.residentialStatus,
      category: category ?? this.category,
      gender: gender ?? this.gender,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'pan': pan,
    'aadhaar': aadhaar,
    'dob': dob?.toIso8601String(),
    'residentialStatus': residentialStatus.name,
    'category': category.name,
    'gender': gender.name,
  };

  factory TaxpayerProfile.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};
    return TaxpayerProfile(
      name: source['name'] as String? ?? '',
      pan: source['pan'] as String? ?? '',
      aadhaar: source['aadhaar'] as String? ?? '',
      dob: DateTime.tryParse(source['dob'] as String? ?? ''),
      residentialStatus: ResidentialStatus.values.firstWhere(
        (item) => item.name == source['residentialStatus'],
        orElse: () => ResidentialStatus.resident,
      ),
      category: TaxpayerCategory.values.firstWhere(
        (item) => item.name == source['category'],
        orElse: () => TaxpayerCategory.individual,
      ),
      gender: Gender.values.firstWhere(
        (item) => item.name == source['gender'],
        orElse: () => Gender.notApplicable,
      ),
    );
  }
}

@immutable
class IncomeInputs {
  const IncomeInputs({
    this.basicSalary = 0,
    this.hra = 0,
    this.hraExemption = 0,
    this.lta = 0,
    this.ltaExemption = 0,
    this.bonus = 0,
    this.commission = 0,
    this.gratuity = 0,
    this.gratuityExemption = 0,
    this.leaveEncashment = 0,
    this.leaveEncashmentExemption = 0,
    this.perquisites = 0,
    this.employerPf = 0,
    this.professionalTax = 0,
    this.otherAllowances = 0,
    this.housePropertyAnnualValue = 0,
    this.municipalTax = 0,
    this.homeLoanInterest = 0,
    this.isSelfOccupied = true,
    this.businessIncome = 0,
    this.presumptiveIncome = 0,
    this.professionalIncome = 0,
    this.stcg111A = 0,
    this.stcgOther = 0,
    this.ltcg112A = 0,
    this.ltcgOther = 0,
    this.interestIncome = 0,
    this.dividendIncome = 0,
    this.lotteryIncome = 0,
    this.giftsIncome = 0,
    this.foreignIncome = 0,
    this.agriculturalIncome = 0,
  });

  final int basicSalary;
  final int hra;
  final int hraExemption;
  final int lta;
  final int ltaExemption;
  final int bonus;
  final int commission;
  final int gratuity;
  final int gratuityExemption;
  final int leaveEncashment;
  final int leaveEncashmentExemption;
  final int perquisites;
  final int employerPf;
  final int professionalTax;
  final int otherAllowances;

  final int housePropertyAnnualValue;
  final int municipalTax;
  final int homeLoanInterest;
  final bool isSelfOccupied;

  final int businessIncome;
  final int presumptiveIncome;
  final int professionalIncome;

  final int stcg111A;
  final int stcgOther;
  final int ltcg112A;
  final int ltcgOther;

  final int interestIncome;
  final int dividendIncome;
  final int lotteryIncome;
  final int giftsIncome;
  final int foreignIncome;
  final int agriculturalIncome;

  int get grossSalary =>
      basicSalary +
      hra +
      lta +
      bonus +
      commission +
      gratuity +
      leaveEncashment +
      perquisites +
      employerPf +
      otherAllowances;

  int get salaryExemptions =>
      hraExemption +
      ltaExemption +
      gratuityExemption +
      leaveEncashmentExemption;

  int get businessProfessionIncome =>
      businessIncome + presumptiveIncome + professionalIncome;

  int get capitalGains => stcg111A + stcgOther + ltcg112A + ltcgOther;

  int get otherSources =>
      interestIncome +
      dividendIncome +
      lotteryIncome +
      giftsIncome +
      foreignIncome;

  bool get hasBusinessOrProfession => businessProfessionIncome > 0;
  bool get hasSpecialRateIncome =>
      stcg111A > 0 || ltcg112A > 0 || ltcgOther > 0 || lotteryIncome > 0;

  IncomeInputs copyWith({
    int? basicSalary,
    int? hra,
    int? hraExemption,
    int? lta,
    int? ltaExemption,
    int? bonus,
    int? commission,
    int? gratuity,
    int? gratuityExemption,
    int? leaveEncashment,
    int? leaveEncashmentExemption,
    int? perquisites,
    int? employerPf,
    int? professionalTax,
    int? otherAllowances,
    int? housePropertyAnnualValue,
    int? municipalTax,
    int? homeLoanInterest,
    bool? isSelfOccupied,
    int? businessIncome,
    int? presumptiveIncome,
    int? professionalIncome,
    int? stcg111A,
    int? stcgOther,
    int? ltcg112A,
    int? ltcgOther,
    int? interestIncome,
    int? dividendIncome,
    int? lotteryIncome,
    int? giftsIncome,
    int? foreignIncome,
    int? agriculturalIncome,
  }) {
    return IncomeInputs(
      basicSalary: basicSalary ?? this.basicSalary,
      hra: hra ?? this.hra,
      hraExemption: hraExemption ?? this.hraExemption,
      lta: lta ?? this.lta,
      ltaExemption: ltaExemption ?? this.ltaExemption,
      bonus: bonus ?? this.bonus,
      commission: commission ?? this.commission,
      gratuity: gratuity ?? this.gratuity,
      gratuityExemption: gratuityExemption ?? this.gratuityExemption,
      leaveEncashment: leaveEncashment ?? this.leaveEncashment,
      leaveEncashmentExemption:
          leaveEncashmentExemption ?? this.leaveEncashmentExemption,
      perquisites: perquisites ?? this.perquisites,
      employerPf: employerPf ?? this.employerPf,
      professionalTax: professionalTax ?? this.professionalTax,
      otherAllowances: otherAllowances ?? this.otherAllowances,
      housePropertyAnnualValue:
          housePropertyAnnualValue ?? this.housePropertyAnnualValue,
      municipalTax: municipalTax ?? this.municipalTax,
      homeLoanInterest: homeLoanInterest ?? this.homeLoanInterest,
      isSelfOccupied: isSelfOccupied ?? this.isSelfOccupied,
      businessIncome: businessIncome ?? this.businessIncome,
      presumptiveIncome: presumptiveIncome ?? this.presumptiveIncome,
      professionalIncome: professionalIncome ?? this.professionalIncome,
      stcg111A: stcg111A ?? this.stcg111A,
      stcgOther: stcgOther ?? this.stcgOther,
      ltcg112A: ltcg112A ?? this.ltcg112A,
      ltcgOther: ltcgOther ?? this.ltcgOther,
      interestIncome: interestIncome ?? this.interestIncome,
      dividendIncome: dividendIncome ?? this.dividendIncome,
      lotteryIncome: lotteryIncome ?? this.lotteryIncome,
      giftsIncome: giftsIncome ?? this.giftsIncome,
      foreignIncome: foreignIncome ?? this.foreignIncome,
      agriculturalIncome: agriculturalIncome ?? this.agriculturalIncome,
    );
  }

  Map<String, dynamic> toMap() => {
    'basicSalary': basicSalary,
    'hra': hra,
    'hraExemption': hraExemption,
    'lta': lta,
    'ltaExemption': ltaExemption,
    'bonus': bonus,
    'commission': commission,
    'gratuity': gratuity,
    'gratuityExemption': gratuityExemption,
    'leaveEncashment': leaveEncashment,
    'leaveEncashmentExemption': leaveEncashmentExemption,
    'perquisites': perquisites,
    'employerPf': employerPf,
    'professionalTax': professionalTax,
    'otherAllowances': otherAllowances,
    'housePropertyAnnualValue': housePropertyAnnualValue,
    'municipalTax': municipalTax,
    'homeLoanInterest': homeLoanInterest,
    'isSelfOccupied': isSelfOccupied,
    'businessIncome': businessIncome,
    'presumptiveIncome': presumptiveIncome,
    'professionalIncome': professionalIncome,
    'stcg111A': stcg111A,
    'stcgOther': stcgOther,
    'ltcg112A': ltcg112A,
    'ltcgOther': ltcgOther,
    'interestIncome': interestIncome,
    'dividendIncome': dividendIncome,
    'lotteryIncome': lotteryIncome,
    'giftsIncome': giftsIncome,
    'foreignIncome': foreignIncome,
    'agriculturalIncome': agriculturalIncome,
  };

  factory IncomeInputs.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};
    int read(String key) => (source[key] as num?)?.round() ?? 0;
    return IncomeInputs(
      basicSalary: read('basicSalary'),
      hra: read('hra'),
      hraExemption: read('hraExemption'),
      lta: read('lta'),
      ltaExemption: read('ltaExemption'),
      bonus: read('bonus'),
      commission: read('commission'),
      gratuity: read('gratuity'),
      gratuityExemption: read('gratuityExemption'),
      leaveEncashment: read('leaveEncashment'),
      leaveEncashmentExemption: read('leaveEncashmentExemption'),
      perquisites: read('perquisites'),
      employerPf: read('employerPf'),
      professionalTax: read('professionalTax'),
      otherAllowances: read('otherAllowances'),
      housePropertyAnnualValue: read('housePropertyAnnualValue'),
      municipalTax: read('municipalTax'),
      homeLoanInterest: read('homeLoanInterest'),
      isSelfOccupied: source['isSelfOccupied'] as bool? ?? true,
      businessIncome: read('businessIncome'),
      presumptiveIncome: read('presumptiveIncome'),
      professionalIncome: read('professionalIncome'),
      stcg111A: read('stcg111A'),
      stcgOther: read('stcgOther'),
      ltcg112A: read('ltcg112A'),
      ltcgOther: read('ltcgOther'),
      interestIncome: read('interestIncome'),
      dividendIncome: read('dividendIncome'),
      lotteryIncome: read('lotteryIncome'),
      giftsIncome: read('giftsIncome'),
      foreignIncome: read('foreignIncome'),
      agriculturalIncome: read('agriculturalIncome'),
    );
  }
}

@immutable
class DeductionInputs {
  const DeductionInputs({
    this.section80CManual = 0,
    this.section80CCC = 0,
    this.section80CCD1 = 0,
    this.section80CCD1B = 0,
    this.section80CCD2 = 0,
    this.section80D = 0,
    this.section80DD = 0,
    this.section80DDB = 0,
    this.section80E = 0,
    this.section80EE = 0,
    this.section80EEA = 0,
    this.section80EEB = 0,
    this.section80G = 0,
    this.section80GG = 0,
    this.section80GGA = 0,
    this.section80GGC = 0,
    this.section80TTA = 0,
    this.section80TTB = 0,
    this.section80U = 0,
    this.nps = 0,
    this.epf = 0,
    this.ppf = 0,
    this.elss = 0,
    this.nsc = 0,
    this.lifeInsurance = 0,
    this.homeLoanPrincipal = 0,
  });

  final int section80CManual;
  final int section80CCC;
  final int section80CCD1;
  final int section80CCD1B;
  final int section80CCD2;
  final int section80D;
  final int section80DD;
  final int section80DDB;
  final int section80E;
  final int section80EE;
  final int section80EEA;
  final int section80EEB;
  final int section80G;
  final int section80GG;
  final int section80GGA;
  final int section80GGC;
  final int section80TTA;
  final int section80TTB;
  final int section80U;
  final int nps;
  final int epf;
  final int ppf;
  final int elss;
  final int nsc;
  final int lifeInsurance;
  final int homeLoanPrincipal;

  int get section80CComponents =>
      epf + ppf + elss + nsc + lifeInsurance + homeLoanPrincipal;

  int get declared80C => section80CManual > section80CComponents
      ? section80CManual
      : section80CComponents;

  DeductionInputs copyWith({
    int? section80CManual,
    int? section80CCC,
    int? section80CCD1,
    int? section80CCD1B,
    int? section80CCD2,
    int? section80D,
    int? section80DD,
    int? section80DDB,
    int? section80E,
    int? section80EE,
    int? section80EEA,
    int? section80EEB,
    int? section80G,
    int? section80GG,
    int? section80GGA,
    int? section80GGC,
    int? section80TTA,
    int? section80TTB,
    int? section80U,
    int? nps,
    int? epf,
    int? ppf,
    int? elss,
    int? nsc,
    int? lifeInsurance,
    int? homeLoanPrincipal,
  }) {
    return DeductionInputs(
      section80CManual: section80CManual ?? this.section80CManual,
      section80CCC: section80CCC ?? this.section80CCC,
      section80CCD1: section80CCD1 ?? this.section80CCD1,
      section80CCD1B: section80CCD1B ?? this.section80CCD1B,
      section80CCD2: section80CCD2 ?? this.section80CCD2,
      section80D: section80D ?? this.section80D,
      section80DD: section80DD ?? this.section80DD,
      section80DDB: section80DDB ?? this.section80DDB,
      section80E: section80E ?? this.section80E,
      section80EE: section80EE ?? this.section80EE,
      section80EEA: section80EEA ?? this.section80EEA,
      section80EEB: section80EEB ?? this.section80EEB,
      section80G: section80G ?? this.section80G,
      section80GG: section80GG ?? this.section80GG,
      section80GGA: section80GGA ?? this.section80GGA,
      section80GGC: section80GGC ?? this.section80GGC,
      section80TTA: section80TTA ?? this.section80TTA,
      section80TTB: section80TTB ?? this.section80TTB,
      section80U: section80U ?? this.section80U,
      nps: nps ?? this.nps,
      epf: epf ?? this.epf,
      ppf: ppf ?? this.ppf,
      elss: elss ?? this.elss,
      nsc: nsc ?? this.nsc,
      lifeInsurance: lifeInsurance ?? this.lifeInsurance,
      homeLoanPrincipal: homeLoanPrincipal ?? this.homeLoanPrincipal,
    );
  }

  Map<String, dynamic> toMap() => {
    'section80CManual': section80CManual,
    'section80CCC': section80CCC,
    'section80CCD1': section80CCD1,
    'section80CCD1B': section80CCD1B,
    'section80CCD2': section80CCD2,
    'section80D': section80D,
    'section80DD': section80DD,
    'section80DDB': section80DDB,
    'section80E': section80E,
    'section80EE': section80EE,
    'section80EEA': section80EEA,
    'section80EEB': section80EEB,
    'section80G': section80G,
    'section80GG': section80GG,
    'section80GGA': section80GGA,
    'section80GGC': section80GGC,
    'section80TTA': section80TTA,
    'section80TTB': section80TTB,
    'section80U': section80U,
    'nps': nps,
    'epf': epf,
    'ppf': ppf,
    'elss': elss,
    'nsc': nsc,
    'lifeInsurance': lifeInsurance,
    'homeLoanPrincipal': homeLoanPrincipal,
  };

  factory DeductionInputs.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};
    int read(String key) => (source[key] as num?)?.round() ?? 0;
    return DeductionInputs(
      section80CManual: read('section80CManual'),
      section80CCC: read('section80CCC'),
      section80CCD1: read('section80CCD1'),
      section80CCD1B: read('section80CCD1B'),
      section80CCD2: read('section80CCD2'),
      section80D: read('section80D'),
      section80DD: read('section80DD'),
      section80DDB: read('section80DDB'),
      section80E: read('section80E'),
      section80EE: read('section80EE'),
      section80EEA: read('section80EEA'),
      section80EEB: read('section80EEB'),
      section80G: read('section80G'),
      section80GG: read('section80GG'),
      section80GGA: read('section80GGA'),
      section80GGC: read('section80GGC'),
      section80TTA: read('section80TTA'),
      section80TTB: read('section80TTB'),
      section80U: read('section80U'),
      nps: read('nps'),
      epf: read('epf'),
      ppf: read('ppf'),
      elss: read('elss'),
      nsc: read('nsc'),
      lifeInsurance: read('lifeInsurance'),
      homeLoanPrincipal: read('homeLoanPrincipal'),
    );
  }
}

@immutable
class TaxPaymentInputs {
  const TaxPaymentInputs({
    this.tdsTcs = 0,
    this.advanceTaxJune = 0,
    this.advanceTaxSeptember = 0,
    this.advanceTaxDecember = 0,
    this.advanceTaxMarch = 0,
    this.selfAssessmentTax = 0,
    this.returnDueDate,
    this.returnFilingDate,
    this.selfAssessmentPaymentDate,
  });

  final int tdsTcs;
  final int advanceTaxJune;
  final int advanceTaxSeptember;
  final int advanceTaxDecember;
  final int advanceTaxMarch;
  final int selfAssessmentTax;
  final DateTime? returnDueDate;
  final DateTime? returnFilingDate;
  final DateTime? selfAssessmentPaymentDate;

  int get advanceTaxPaid =>
      advanceTaxJune +
      advanceTaxSeptember +
      advanceTaxDecember +
      advanceTaxMarch;

  int get totalTaxesPaid => tdsTcs + advanceTaxPaid + selfAssessmentTax;

  TaxPaymentInputs copyWith({
    int? tdsTcs,
    int? advanceTaxJune,
    int? advanceTaxSeptember,
    int? advanceTaxDecember,
    int? advanceTaxMarch,
    int? selfAssessmentTax,
    DateTime? returnDueDate,
    DateTime? returnFilingDate,
    DateTime? selfAssessmentPaymentDate,
  }) {
    return TaxPaymentInputs(
      tdsTcs: tdsTcs ?? this.tdsTcs,
      advanceTaxJune: advanceTaxJune ?? this.advanceTaxJune,
      advanceTaxSeptember: advanceTaxSeptember ?? this.advanceTaxSeptember,
      advanceTaxDecember: advanceTaxDecember ?? this.advanceTaxDecember,
      advanceTaxMarch: advanceTaxMarch ?? this.advanceTaxMarch,
      selfAssessmentTax: selfAssessmentTax ?? this.selfAssessmentTax,
      returnDueDate: returnDueDate ?? this.returnDueDate,
      returnFilingDate: returnFilingDate ?? this.returnFilingDate,
      selfAssessmentPaymentDate:
          selfAssessmentPaymentDate ?? this.selfAssessmentPaymentDate,
    );
  }

  Map<String, dynamic> toMap() => {
    'tdsTcs': tdsTcs,
    'advanceTaxJune': advanceTaxJune,
    'advanceTaxSeptember': advanceTaxSeptember,
    'advanceTaxDecember': advanceTaxDecember,
    'advanceTaxMarch': advanceTaxMarch,
    'selfAssessmentTax': selfAssessmentTax,
    'returnDueDate': returnDueDate?.toIso8601String(),
    'returnFilingDate': returnFilingDate?.toIso8601String(),
    'selfAssessmentPaymentDate': selfAssessmentPaymentDate?.toIso8601String(),
  };

  factory TaxPaymentInputs.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};
    int read(String key) => (source[key] as num?)?.round() ?? 0;
    return TaxPaymentInputs(
      tdsTcs: read('tdsTcs'),
      advanceTaxJune: read('advanceTaxJune'),
      advanceTaxSeptember: read('advanceTaxSeptember'),
      advanceTaxDecember: read('advanceTaxDecember'),
      advanceTaxMarch: read('advanceTaxMarch'),
      selfAssessmentTax: read('selfAssessmentTax'),
      returnDueDate: DateTime.tryParse(
        source['returnDueDate'] as String? ?? '',
      ),
      returnFilingDate: DateTime.tryParse(
        source['returnFilingDate'] as String? ?? '',
      ),
      selfAssessmentPaymentDate: DateTime.tryParse(
        source['selfAssessmentPaymentDate'] as String? ?? '',
      ),
    );
  }
}

@immutable
class IncomeTaxDraft {
  const IncomeTaxDraft({
    this.id,
    this.financialYear = FinancialYear.fy2025_26,
    this.profile = const TaxpayerProfile(),
    this.income = const IncomeInputs(),
    this.deductions = const DeductionInputs(),
    this.payments = const TaxPaymentInputs(),
    this.status = CalculationStatus.draft,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  final String? id;
  final FinancialYear financialYear;
  final TaxpayerProfile profile;
  final IncomeInputs income;
  final DeductionInputs deductions;
  final TaxPaymentInputs payments;
  final CalculationStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  IncomeTaxDraft copyWith({
    String? id,
    FinancialYear? financialYear,
    TaxpayerProfile? profile,
    IncomeInputs? income,
    DeductionInputs? deductions,
    TaxPaymentInputs? payments,
    CalculationStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return IncomeTaxDraft(
      id: id ?? this.id,
      financialYear: financialYear ?? this.financialYear,
      profile: profile ?? this.profile,
      income: income ?? this.income,
      deductions: deductions ?? this.deductions,
      payments: payments ?? this.payments,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toMap() => {
    'financialYear': financialYear.storageValue,
    'statutoryYearLabel': financialYear.statutoryYearLabel,
    'profile': profile.toMap(),
    'income': income.toMap(),
    'deductions': deductions.toMap(),
    'payments': payments.toMap(),
    'status': status.name,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
  };

  factory IncomeTaxDraft.fromMap(String id, Map<String, dynamic> map) {
    return IncomeTaxDraft(
      id: id,
      financialYear: FinancialYear.fromStorage(map['financialYear'] as String?),
      profile: TaxpayerProfile.fromMap(map['profile'] as Map<String, dynamic>?),
      income: IncomeInputs.fromMap(map['income'] as Map<String, dynamic>?),
      deductions: DeductionInputs.fromMap(
        map['deductions'] as Map<String, dynamic>?,
      ),
      payments: TaxPaymentInputs.fromMap(
        map['payments'] as Map<String, dynamic>?,
      ),
      status: CalculationStatus.values.firstWhere(
        (item) => item.name == map['status'],
        orElse: () => CalculationStatus.draft,
      ),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }
}

@immutable
class SlabTaxLine {
  const SlabTaxLine({
    required this.label,
    required this.taxableAmount,
    required this.rateBasisPoints,
    required this.tax,
  });

  final String label;
  final int taxableAmount;
  final int rateBasisPoints;
  final int tax;
}

@immutable
class AdvanceTaxSchedule {
  const AdvanceTaxSchedule({
    required this.june15,
    required this.september15,
    required this.december15,
    required this.march15,
  });

  final int june15;
  final int september15;
  final int december15;
  final int march15;
}

@immutable
class TaxComputationResult {
  const TaxComputationResult({
    required this.regime,
    required this.grossIncome,
    required this.salaryDeductions,
    required this.chapterVIADeductions,
    required this.totalDeductions,
    required this.taxableIncome,
    required this.normalIncome,
    required this.specialRateIncome,
    required this.slabTax,
    required this.specialRateTax,
    required this.surcharge,
    required this.marginalRelief,
    required this.rebate,
    required this.cess,
    required this.interest234A,
    required this.interest234B,
    required this.interest234C,
    required this.penalty,
    required this.netTax,
    required this.totalPaid,
    required this.payable,
    required this.refund,
    required this.slabLines,
    required this.advanceTaxSchedule,
    required this.warnings,
  });

  final TaxRegime regime;
  final int grossIncome;
  final int salaryDeductions;
  final int chapterVIADeductions;
  final int totalDeductions;
  final int taxableIncome;
  final int normalIncome;
  final int specialRateIncome;
  final int slabTax;
  final int specialRateTax;
  final int surcharge;
  final int marginalRelief;
  final int rebate;
  final int cess;
  final int interest234A;
  final int interest234B;
  final int interest234C;
  final int penalty;
  final int netTax;
  final int totalPaid;
  final int payable;
  final int refund;
  final List<SlabTaxLine> slabLines;
  final AdvanceTaxSchedule advanceTaxSchedule;
  final List<String> warnings;
}

@immutable
class RegimeComparison {
  const RegimeComparison({
    required this.oldRegime,
    required this.newRegime,
    required this.recommendedRegime,
    required this.taxSaving,
    required this.percentageSavedBasisPoints,
    required this.suggestedItr,
    required this.planningSuggestions,
  });

  final TaxComputationResult oldRegime;
  final TaxComputationResult newRegime;
  final TaxRegime recommendedRegime;
  final int taxSaving;
  final int percentageSavedBasisPoints;
  final String suggestedItr;
  final List<String> planningSuggestions;
}
