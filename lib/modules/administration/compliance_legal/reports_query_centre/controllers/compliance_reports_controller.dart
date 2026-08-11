import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/compliance_models.dart';
import '../repositories/compliance_reports_repository.dart';
import '../services/compliance_report_services.dart';

class ComplianceReportsController extends ChangeNotifier {
  ComplianceReportsController({required this.repository});
  final ComplianceReportsRepository repository;
  final ComplianceReportEngine engine = ComplianceReportEngine();
  List<ComplianceRecord> records = [];
  List<ComplianceQuery> queries = [];
  ReportFilters filters = const ReportFilters();
  bool loading = true;
  String? error;
  int page = 0;
  int pageSize = 20;
  Timer? _debounce;
  StreamSubscription<List<ComplianceQuery>>? _queries;
  ComplianceKpis get kpis => ComplianceKpis.fromRecords(records);
  List<ComplianceRecord> get filtered =>
      records.where(filters.matches).toList();
  List<ComplianceRecord> report(ReportDefinition definition) =>
      engine.generate(records, definition, filters);
  Future<void> initialize() async {
    _queries = repository.watchQueries().listen(
      (value) {
        queries = value;
        notifyListeners();
      },
      onError: (Object e) {
        error = e.toString();
        notifyListeners();
      },
    );
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      records = await repository.loadRecords();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      filters = filters.copyWith(search: value);
      page = 0;
      notifyListeners();
    });
  }

  void setStatus(String value) {
    filters = filters.copyWith(status: value);
    page = 0;
    notifyListeners();
  }

  void setPriority(String value) {
    filters = filters.copyWith(priority: value);
    page = 0;
    notifyListeners();
  }

  void clearFilters() {
    filters = const ReportFilters();
    page = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queries?.cancel();
    super.dispose();
  }
}
