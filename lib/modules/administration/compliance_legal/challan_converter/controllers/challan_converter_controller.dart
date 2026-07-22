import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/challan_extraction_model.dart';
import '../models/challan_queue_item.dart';
import '../services/challan_export_service.dart';
import '../services/challan_extraction_service.dart';
import '../services/challan_pdf_text_service.dart';

class ChallanConverterController extends ChangeNotifier {
  ChallanConverterController({
    ChallanPdfTextService? pdfTextService,
    ChallanExtractionService? extractionService,
    ChallanExportService? exportService,
  }) : _pdfTextService = pdfTextService ?? ChallanPdfTextService(),
       _extractionService = extractionService ?? ChallanExtractionService(),
       _exportService = exportService ?? ChallanExportService();

  final ChallanPdfTextService _pdfTextService;
  final ChallanExtractionService _extractionService;
  final ChallanExportService _exportService;

  final List<ChallanQueueItem> queue = <ChallanQueueItem>[];
  final List<ChallanExtractionModel> records = <ChallanExtractionModel>[];

  final Set<String> selectedRecordIds = <String>{};

  bool isProcessing = false;
  bool isPaused = false;
  bool isCancelled = false;

  String search = '';
  String verificationFilter = 'All';
  String challanTypeFilter = 'All';

  int pageSize = 50;
  int currentPage = 0;

  int get totalFiles => queue.length;

  int get processedFiles =>
      queue.where((item) => item.status == 'Processed').length;

  int get failedFiles => queue.where((item) => item.status == 'Failed').length;

  int get pendingFiles => queue
      .where((item) => item.status == 'Pending' || item.status == 'Processing')
      .length;

  double get progress {
    if (totalFiles == 0) {
      return 0;
    }

    return (processedFiles + failedFiles) / totalFiles;
  }

  List<ChallanExtractionModel> get filteredRecords {
    final query = search.trim().toLowerCase();

    return records.where((record) {
      final matchesSearch =
          query.isEmpty ||
          record.sourceFileName.toLowerCase().contains(query) ||
          record.pan.toLowerCase().contains(query) ||
          record.tan.toLowerCase().contains(query) ||
          record.bsrCode.toLowerCase().contains(query) ||
          record.name.toLowerCase().contains(query) ||
          record.challanType.toLowerCase().contains(query);

      final matchesVerification =
          verificationFilter == 'All' ||
          record.verificationStatus == verificationFilter;

      final matchesType =
          challanTypeFilter == 'All' || record.challanType == challanTypeFilter;

      return matchesSearch && matchesVerification && matchesType;
    }).toList();
  }

  List<ChallanExtractionModel> get visibleRecords {
    final data = filteredRecords;

    if (pageSize == -1) {
      return data;
    }

    final start = currentPage * pageSize;

    if (start >= data.length) {
      return const <ChallanExtractionModel>[];
    }

    final end = (start + pageSize).clamp(0, data.length);
    return data.sublist(start, end);
  }

  Future<void> pickFiles({required bool allowMultiple}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      allowMultiple: allowMultiple,
      withData: true,
    );

    if (result == null) {
      return;
    }

    final availableSlots = 500 - queue.length;

    for (final file in result.files.take(availableSlots)) {
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        continue;
      }

      final duplicate = queue.any(
        (item) => item.fileName == file.name && item.fileSize == bytes.length,
      );

      if (duplicate) {
        continue;
      }

      queue.add(
        ChallanQueueItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${file.name}',
          fileName: file.name,
          bytes: bytes,
          fileSize: bytes.length,
        ),
      );
    }

    notifyListeners();
  }

  void removeQueueItem(String id) {
    if (isProcessing) {
      return;
    }

    queue.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> processQueue() async {
    if (isProcessing || queue.isEmpty) {
      return;
    }

    isProcessing = true;
    isPaused = false;
    isCancelled = false;
    notifyListeners();

    for (final item in queue) {
      if (isCancelled) {
        break;
      }

      while (isPaused && !isCancelled) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      if (item.status == 'Processed') {
        continue;
      }

      item.status = 'Processing';
      item.errorMessage = '';
      notifyListeners();

      final stopwatch = Stopwatch()..start();

      try {
        final text = await _pdfTextService.extractText(item.bytes);

        final record = _extractionService.extract(
          id: item.id,
          fileName: item.fileName,
          bytes: item.bytes,
          text: text,
          processingTimeMilliseconds: stopwatch.elapsedMilliseconds,
        );

        records.removeWhere((existing) => existing.id == record.id);
        records.add(record);

        item.status = 'Processed';
      } catch (error) {
        item.status = 'Failed';
        item.errorMessage = error.toString();
      }

      stopwatch.stop();
      notifyListeners();

      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    isProcessing = false;
    isPaused = false;
    notifyListeners();
  }

  void pause() {
    if (!isProcessing) {
      return;
    }

    isPaused = true;
    notifyListeners();
  }

  void resume() {
    if (!isProcessing) {
      return;
    }

    isPaused = false;
    notifyListeners();
  }

  void cancel() {
    isCancelled = true;
    isPaused = false;
    notifyListeners();
  }

  void retryFailed() {
    for (final item in queue) {
      if (item.status == 'Failed') {
        item.status = 'Pending';
        item.errorMessage = '';
      }
    }

    notifyListeners();
  }

  void clearCompleted() {
    if (isProcessing) {
      return;
    }

    final completedIds = queue
        .where((item) => item.status == 'Processed')
        .map((item) => item.id)
        .toSet();

    queue.removeWhere((item) => completedIds.contains(item.id));

    notifyListeners();
  }

  void deleteRecord(String id) {
    records.removeWhere((record) => record.id == id);
    selectedRecordIds.remove(id);
    notifyListeners();
  }

  void toggleRecordSelection(String id, bool selected) {
    if (selected) {
      selectedRecordIds.add(id);
    } else {
      selectedRecordIds.remove(id);
    }

    notifyListeners();
  }

  void deleteSelected() {
    records.removeWhere((record) => selectedRecordIds.contains(record.id));
    selectedRecordIds.clear();
    notifyListeners();
  }

  Future<void> exportCsv({bool selectedOnly = false}) async {
    final data = selectedOnly
        ? records
              .where((record) => selectedRecordIds.contains(record.id))
              .toList()
        : filteredRecords;

    await _exportService.exportCsv(data);
  }

  Future<void> exportJson({bool selectedOnly = false}) async {
    final data = selectedOnly
        ? records
              .where((record) => selectedRecordIds.contains(record.id))
              .toList()
        : filteredRecords;

    await _exportService.exportJson(data);
  }
}
