import 'package:flutter/foundation.dart';

import '../models/compliance_calendar_model.dart';
import '../repositories/compliance_calendar_repository.dart';

enum ComplianceViewMode { month, week, agenda }

class ComplianceCalendarController extends ChangeNotifier {
  ComplianceCalendarController({
    required ComplianceCalendarRepository repository,
  }) : _repository = repository;

  final ComplianceCalendarRepository _repository;

  String search = '';
  String financialYear = 'FY 2026–27';
  String category = 'All';
  String status = 'All';
  String priority = 'All';
  String department = 'All';
  String branch = 'All';

  String? kpiFilter;

  DateTime focusedDate = DateTime.now();
  DateTime? selectedDate;

  ComplianceViewMode viewMode = ComplianceViewMode.month;

  List<ComplianceCalendarModel> applyFilters(
    List<ComplianceCalendarModel> records,
  ) {
    final query = search.trim().toLowerCase();

    return records.where((record) {
      final matchesSearch =
          query.isEmpty ||
          record.title.toLowerCase().contains(query) ||
          record.description.toLowerCase().contains(query) ||
          record.category.toLowerCase().contains(query) ||
          record.authority.toLowerCase().contains(query) ||
          record.act.toLowerCase().contains(query);

      final matchesFinancialYear =
          financialYear == 'All' || record.financialYear == financialYear;

      final matchesCategory = category == 'All' || record.category == category;

      final matchesStatus = status == 'All' || record.status == status;

      final matchesPriority = priority == 'All' || record.priority == priority;

      final matchesDepartment =
          department == 'All' || record.department == department;

      final matchesBranch = branch == 'All' || record.branch == branch;

      final matchesKpi = _matchesKpi(record);

      return matchesSearch &&
          matchesFinancialYear &&
          matchesCategory &&
          matchesStatus &&
          matchesPriority &&
          matchesDepartment &&
          matchesBranch &&
          matchesKpi;
    }).toList();
  }

  bool _matchesKpi(ComplianceCalendarModel record) {
    if (kpiFilter == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      record.dueDate.year,
      record.dueDate.month,
      record.dueDate.day,
    );
    final difference = due.difference(today).inDays;

    switch (kpiFilter) {
      case 'Completed':
        return record.status == 'Completed';
      case 'Pending':
        return record.status == 'Pending';
      case 'Overdue':
        return record.status != 'Completed' && difference < 0;
      case 'Due Today':
        return difference == 0;
      case 'Due in 7 Days':
        return difference >= 0 && difference <= 7;
      case 'Due in 30 Days':
        return difference >= 0 && difference <= 30;
      case 'High Priority':
        return record.priority == 'High' || record.priority == 'Critical';
      default:
        return true;
    }
  }

  void setKpiFilter(String? value) {
    kpiFilter = kpiFilter == value ? null : value;
    notifyListeners();
  }

  void setViewMode(ComplianceViewMode value) {
    viewMode = value;
    notifyListeners();
  }

  void setFocusedDate(DateTime value) {
    focusedDate = value;
    notifyListeners();
  }

  void selectDate(DateTime value) {
    selectedDate = value;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  Future<void> create({
    required ComplianceCalendarModel item,
    required String userUid,
  }) {
    return _repository.create(item: item, userUid: userUid);
  }

  Future<void> update({
    required ComplianceCalendarModel item,
    required String userUid,
  }) {
    return _repository.update(item: item, userUid: userUid);
  }

  Future<void> updateStatus({
    required String id,
    required String status,
    required String userUid,
  }) {
    return _repository.updateStatus(id: id, status: status, userUid: userUid);
  }

  Future<void> archive({required String id, required String userUid}) {
    return _repository.archive(id: id, userUid: userUid);
  }
}
