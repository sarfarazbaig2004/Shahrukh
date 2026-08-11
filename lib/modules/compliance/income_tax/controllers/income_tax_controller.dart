import 'package:flutter/foundation.dart';

import '../models/income_tax_models.dart';
import '../repositories/income_tax_repository.dart';
import '../services/income_tax_engine.dart';

class IncomeTaxController extends ChangeNotifier {
  IncomeTaxController({
    required this.companyId,
    required this.userId,
    required IncomeTaxRepository repository,
    IncomeTaxEngine engine = const IncomeTaxEngine(),
  }) : _repository = repository,
       _engine = engine {
    _comparison = _engine.compare(_draft);
  }

  final String companyId;
  final String userId;
  final IncomeTaxRepository _repository;
  final IncomeTaxEngine _engine;

  IncomeTaxDraft _draft = const IncomeTaxDraft();
  late RegimeComparison _comparison;
  List<IncomeTaxDraft> _history = const [];
  bool _isSaving = false;
  bool _isLoadingHistory = false;
  String? _error;

  IncomeTaxDraft get draft => _draft;
  RegimeComparison get comparison => _comparison;
  List<IncomeTaxDraft> get history => _history;
  bool get isSaving => _isSaving;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;

  void updateDraft(IncomeTaxDraft value) {
    _draft = value;
    _comparison = _engine.compare(_draft);
    _error = null;
    notifyListeners();
  }

  void setFinancialYear(FinancialYear year) {
    updateDraft(_draft.copyWith(financialYear: year));
  }

  void setProfile(TaxpayerProfile profile) {
    updateDraft(_draft.copyWith(profile: profile));
  }

  void setIncome(IncomeInputs income) {
    updateDraft(_draft.copyWith(income: income));
  }

  void setDeductions(DeductionInputs deductions) {
    updateDraft(_draft.copyWith(deductions: deductions));
  }

  void setPayments(TaxPaymentInputs payments) {
    updateDraft(_draft.copyWith(payments: payments));
  }

  Future<IncomeTaxDraft?> save({required bool asDraft}) async {
    if (_isSaving) return null;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await _repository.save(
        companyId: companyId,
        userId: userId,
        draft: _draft.copyWith(
          status: asDraft
              ? CalculationStatus.draft
              : CalculationStatus.finalised,
        ),
        comparison: _comparison,
      );
      _draft = saved;
      _comparison = _engine.compare(_draft);
      await loadHistory();
      return saved;
    } catch (error) {
      _error = 'Unable to save calculation: $error';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory({String query = ''}) async {
    if (_isLoadingHistory) return;
    _isLoadingHistory = true;
    _error = null;
    notifyListeners();
    try {
      _history = await _repository.search(companyId: companyId, query: query);
    } catch (error) {
      _error = 'Unable to load calculation history: $error';
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> openCalculation(String id) async {
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.findById(companyId: companyId, id: id);
      if (result == null) {
        _error = 'The selected calculation was not found.';
      } else {
        _draft = result;
        _comparison = _engine.compare(_draft);
      }
    } catch (error) {
      _error = 'Unable to open calculation: $error';
    }
    notifyListeners();
  }

  void duplicateCalculation(IncomeTaxDraft source) {
    final now = DateTime.now().toUtc();
    _draft = source.copyWith(
      id: null,
      status: CalculationStatus.draft,
      createdAt: now,
      updatedAt: now,
      createdBy: userId,
      updatedBy: userId,
    );
    // copyWith cannot clear nullable id, so rebuild explicitly.
    _draft = IncomeTaxDraft(
      financialYear: source.financialYear,
      profile: source.profile,
      income: source.income,
      deductions: source.deductions,
      payments: source.payments,
      status: CalculationStatus.draft,
      createdAt: now,
      updatedAt: now,
      createdBy: userId,
      updatedBy: userId,
    );
    _comparison = _engine.compare(_draft);
    notifyListeners();
  }

  Future<void> deleteCalculation(String id) async {
    try {
      await _repository.softDelete(
        companyId: companyId,
        userId: userId,
        id: id,
      );
      await loadHistory();
      if (_draft.id == id) reset();
    } catch (error) {
      _error = 'Unable to delete calculation: $error';
      notifyListeners();
    }
  }

  void reset() {
    _draft = IncomeTaxDraft(financialYear: _draft.financialYear);
    _comparison = _engine.compare(_draft);
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
