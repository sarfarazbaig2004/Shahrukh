import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/income_tax_models.dart';
import '../rules/income_tax_rule_registry.dart';
import 'income_tax_repository.dart';

class FirestoreIncomeTaxRepository implements IncomeTaxRepository {
  FirestoreIncomeTaxRepository({
    FirebaseFirestore? firestore,
    IncomeTaxRuleRegistry ruleRegistry = const IncomeTaxRuleRegistry(),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _ruleRegistry = ruleRegistry;

  final FirebaseFirestore _firestore;
  final IncomeTaxRuleRegistry _ruleRegistry;

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    if (companyId.trim().isEmpty) {
      throw ArgumentError.value(companyId, 'companyId', 'Cannot be empty');
    }
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('incomeTaxCalculations');
  }

  @override
  Future<IncomeTaxDraft> save({
    required String companyId,
    required String userId,
    required IncomeTaxDraft draft,
    required RegimeComparison comparison,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Cannot be empty');
    }

    final now = DateTime.now().toUtc();
    final document = draft.id == null
        ? _collection(companyId).doc()
        : _collection(companyId).doc(draft.id);
    final existingCreatedAt = draft.createdAt ?? now;
    final value = draft.copyWith(
      id: document.id,
      createdAt: existingCreatedAt,
      updatedAt: now,
      createdBy: draft.createdBy ?? userId,
      updatedBy: userId,
    );

    final selectedResult = comparison.recommendedRegime == TaxRegime.oldRegime
        ? comparison.oldRegime
        : comparison.newRegime;
    final yearEnd = value.financialYear == FinancialYear.fy2025_26
        ? DateTime(2026, 3, 31)
        : DateTime(2027, 3, 31);
    final map = value.toMap()
      ..addAll({
        'id': document.id,
        'taxpayerName': value.profile.name,
        'pan': value.profile.pan,
        'aadhaar': value.profile.aadhaar,
        'dob': value.profile.dob?.toIso8601String(),
        'age': value.profile.ageOn(yearEnd),
        'residentialStatus': value.profile.residentialStatus.name,
        'category': value.profile.category.name,
        'financialYearLabel': value.financialYear.label,
        'assessmentYear': value.financialYear.statutoryYearLabel,
        'ruleVersion': _ruleRegistry.forYear(value.financialYear).ruleVersion,
        'salaryIncome': value.income.grossSalary,
        'housePropertyIncome': value.income.housePropertyAnnualValue,
        'businessIncome': value.income.businessProfessionIncome,
        'capitalGain': value.income.capitalGains,
        'otherIncome': value.income.otherSources,
        'grossIncome': selectedResult.grossIncome,
        'totalDeductions': selectedResult.totalDeductions,
        'taxableIncome': selectedResult.taxableIncome,
        'oldRegimeTax': comparison.oldRegime.netTax,
        'newRegimeTax': comparison.newRegime.netTax,
        'recommendedRegime': comparison.recommendedRegime.name,
        'advanceTax': selectedResult.advanceTaxSchedule.march15,
        'interest234A': selectedResult.interest234A,
        'interest234B': selectedResult.interest234B,
        'interest234C': selectedResult.interest234C,
        'rebate': selectedResult.rebate,
        'cess': selectedResult.cess,
        'surcharge': selectedResult.surcharge,
        'netTax': selectedResult.netTax,
        'refund': selectedResult.refund,
        'itrForm': comparison.suggestedItr,
        'calculationSnapshot': {
          'oldRegime': _resultToMap(comparison.oldRegime),
          'newRegime': _resultToMap(comparison.newRegime),
          'taxSaving': comparison.taxSaving,
          'percentageSavedBasisPoints': comparison.percentageSavedBasisPoints,
        },
        'taxpayerNameLower': value.profile.name.trim().toLowerCase(),
        'panUpper': value.profile.pan.trim().toUpperCase(),
        'isDeleted': false,
        'createdAtTimestamp': Timestamp.fromDate(existingCreatedAt),
        'updatedAtTimestamp': Timestamp.fromDate(now),
      });

    await document.set(map, SetOptions(merge: true));
    return value;
  }

  @override
  Future<List<IncomeTaxDraft>> search({
    required String companyId,
    String query = '',
    int limit = 50,
  }) async {
    final safeLimit = limit.clamp(1, 100).toInt();
    final snapshot = await _collection(
      companyId,
    ).orderBy('updatedAtTimestamp', descending: true).limit(safeLimit).get();

    final normalizedQuery = query.trim().toLowerCase();
    final records = snapshot.docs
        .where((doc) => doc.data()['isDeleted'] != true)
        .map((doc) => IncomeTaxDraft.fromMap(doc.id, _normalize(doc.data())))
        .where((draft) {
          if (normalizedQuery.isEmpty) return true;
          return draft.profile.name.toLowerCase().contains(normalizedQuery) ||
              draft.profile.pan.toLowerCase().contains(normalizedQuery) ||
              draft.financialYear.label.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
    return records;
  }

  @override
  Future<IncomeTaxDraft?> findById({
    required String companyId,
    required String id,
  }) async {
    final snapshot = await _collection(companyId).doc(id).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null || data['isDeleted'] == true)
      return null;
    return IncomeTaxDraft.fromMap(snapshot.id, _normalize(data));
  }

  @override
  Future<void> softDelete({
    required String companyId,
    required String userId,
    required String id,
  }) async {
    await _collection(companyId).doc(id).set({
      'isDeleted': true,
      'deletedBy': userId,
      'deletedAtTimestamp': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'updatedAtTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _resultToMap(TaxComputationResult result) => {
    'grossIncome': result.grossIncome,
    'salaryDeductions': result.salaryDeductions,
    'chapterVIADeductions': result.chapterVIADeductions,
    'totalDeductions': result.totalDeductions,
    'taxableIncome': result.taxableIncome,
    'normalIncome': result.normalIncome,
    'specialRateIncome': result.specialRateIncome,
    'slabTax': result.slabTax,
    'specialRateTax': result.specialRateTax,
    'surcharge': result.surcharge,
    'marginalRelief': result.marginalRelief,
    'rebate': result.rebate,
    'cess': result.cess,
    'interest234A': result.interest234A,
    'interest234B': result.interest234B,
    'interest234C': result.interest234C,
    'penalty': result.penalty,
    'netTax': result.netTax,
    'totalPaid': result.totalPaid,
    'payable': result.payable,
    'refund': result.refund,
    'advanceTax': {
      'june15': result.advanceTaxSchedule.june15,
      'september15': result.advanceTaxSchedule.september15,
      'december15': result.advanceTaxSchedule.december15,
      'march15': result.advanceTaxSchedule.march15,
    },
    'warnings': result.warnings,
  };

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    for (final key in const ['createdAt', 'updatedAt']) {
      final value = result[key];
      if (value is Timestamp) result[key] = value.toDate().toIso8601String();
    }
    for (final entry in const {
      'createdAtTimestamp': 'createdAt',
      'updatedAtTimestamp': 'updatedAt',
    }.entries) {
      final value = result[entry.key];
      if (result[entry.value] == null && value is Timestamp) {
        result[entry.value] = value.toDate().toIso8601String();
      }
    }
    return result;
  }
}
