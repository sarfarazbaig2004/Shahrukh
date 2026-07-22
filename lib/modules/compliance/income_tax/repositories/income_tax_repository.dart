import '../models/income_tax_models.dart';

abstract interface class IncomeTaxRepository {
  Future<IncomeTaxDraft> save({
    required String companyId,
    required String userId,
    required IncomeTaxDraft draft,
    required RegimeComparison comparison,
  });

  Future<List<IncomeTaxDraft>> search({
    required String companyId,
    String query = '',
    int limit = 50,
  });

  Future<IncomeTaxDraft?> findById({
    required String companyId,
    required String id,
  });

  Future<void> softDelete({
    required String companyId,
    required String userId,
    required String id,
  });
}
