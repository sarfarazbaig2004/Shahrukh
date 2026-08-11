import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/form10iea_models.dart';
import '../repositories/form10iea_repository.dart';
import '../services/form10iea_pdf_extractor.dart';
import '../services/form10iea_rule_engine.dart';

class Form10IEAController extends ChangeNotifier {
  Form10IEAController({
    required this.repository,
    Form10IEARuleEngine? ruleEngine,
    Form10IEAPdfExtractor? pdfExtractor,
  }) : _ruleEngine = ruleEngine ?? const Form10IEARuleEngine(),
       _pdfExtractor = pdfExtractor ?? Form10IEAPdfExtractor() {
    addAssessee();
  }

  final Form10IEARepository repository;
  final Form10IEARuleEngine _ruleEngine;
  final Form10IEAPdfExtractor _pdfExtractor;

  Form10IEAFinderMode finderMode = Form10IEAFinderMode.uploadBased;

  Form10IEAAssesseeMode assesseeMode = Form10IEAAssesseeMode.single;

  int primaryTabIndex = 0;
  int selectedAssesseeIndex = 0;

  bool isAnalysing = false;
  bool isSaving = false;

  List<Form10IEAAssessmentInput> assessees = <Form10IEAAssessmentInput>[];

  final Map<String, Form10IEAResult> results = <String, Form10IEAResult>{};

  Form10IEAAssessmentInput get activeAssessee =>
      assessees[selectedAssesseeIndex];

  void setPrimaryTab(int value) {
    primaryTabIndex = value;
    notifyListeners();
  }

  void setFinderMode(Form10IEAFinderMode value) {
    finderMode = value;
    notifyListeners();
  }

  void setAssesseeMode(Form10IEAAssesseeMode value) {
    assesseeMode = value;

    if (value == Form10IEAAssesseeMode.single && assessees.length > 1) {
      selectedAssesseeIndex = 0;
    }

    notifyListeners();
  }

  void addAssessee() {
    final config = Form10IEAFinancialYearConfig.current;

    assessees.add(
      Form10IEAAssessmentInput(
        temporaryId:
            'assessee_${DateTime.now().microsecondsSinceEpoch}_${assessees.length}',
        previousYears: config.previousYears
            .map(
              (item) => PreviousYearFilingInput(
                financialYear: item.financialYear,
                assessmentYear: item.assessmentYear,
              ),
            )
            .toList(),
      ),
    );

    selectedAssesseeIndex = assessees.length - 1;
    notifyListeners();
  }

  void duplicateAssessee(int index) {
    final source = assessees[index];

    assessees.add(
      Form10IEAAssessmentInput(
        temporaryId:
            'assessee_${DateTime.now().microsecondsSinceEpoch}_${assessees.length}',
        previousYears: source.previousYears
            .map(
              (item) => item.copyWith(
                fileName: '',
                fileSize: 0,
                extractionStatus: Form10IEAExtractionStatus.idle,
                confirmationStatus: Form10IEAConfirmationStatus.pending,
              ),
            )
            .toList(),
        proposedItr: source.proposedItr,
        isRevisedReturn: source.isRevisedReturn,
      ),
    );

    selectedAssesseeIndex = assessees.length - 1;
    notifyListeners();
  }

  void removeAssessee(int index) {
    if (assessees.length == 1) {
      return;
    }

    results.remove(assessees[index].temporaryId);
    assessees.removeAt(index);

    if (selectedAssesseeIndex >= assessees.length) {
      selectedAssesseeIndex = assessees.length - 1;
    }

    notifyListeners();
  }

  void selectAssessee(int index) {
    selectedAssesseeIndex = index;
    notifyListeners();
  }

  void updatePreviousYear({
    required int assesseeIndex,
    required int yearIndex,
    required PreviousYearFilingInput value,
  }) {
    final assessee = assessees[assesseeIndex];
    final years = List<PreviousYearFilingInput>.from(assessee.previousYears);

    years[yearIndex] = value;

    assessees[assesseeIndex] = assessee.copyWith(previousYears: years);

    results.remove(assessee.temporaryId);
    notifyListeners();
  }

  void setProposedItr({
    required int assesseeIndex,
    required Form10IEAItrType value,
  }) {
    final assessee = assessees[assesseeIndex];

    assessees[assesseeIndex] = assessee.copyWith(proposedItr: value);

    results.remove(assessee.temporaryId);
    notifyListeners();
  }

  Future<void> extractPdf({
    required int assesseeIndex,
    required int yearIndex,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final current = assessees[assesseeIndex].previousYears[yearIndex];

    updatePreviousYear(
      assesseeIndex: assesseeIndex,
      yearIndex: yearIndex,
      value: current.copyWith(
        fileName: fileName,
        fileSize: bytes.length,
        extractionStatus: Form10IEAExtractionStatus.reading,
        errorMessage: '',
      ),
    );

    try {
      final extraction = await _pdfExtractor.extract(bytes);

      final updated = assessees[assesseeIndex].previousYears[yearIndex]
          .copyWith(
            itrType: extraction.itrType,
            panMasked: extraction.panMasked,
            acknowledgementMasked: extraction.acknowledgementMasked,
            selectedRegime: extraction.selectedRegime,
            hasBusinessIncome: extraction.hasBusinessIncome,
            form10ieaFiled: extraction.form10ieaFiled,
            extractionConfidence: extraction.confidence,
            extractionStatus: extraction.needsManualReview
                ? Form10IEAExtractionStatus.needsReview
                : Form10IEAExtractionStatus.awaitingConfirmation,
            confirmationStatus: Form10IEAConfirmationStatus.pending,
          );

      updatePreviousYear(
        assesseeIndex: assesseeIndex,
        yearIndex: yearIndex,
        value: updated,
      );
    } catch (error) {
      final failed = assessees[assesseeIndex].previousYears[yearIndex].copyWith(
        extractionStatus: Form10IEAExtractionStatus.extractionFailed,
        errorMessage: error.toString(),
        confirmationStatus: Form10IEAConfirmationStatus.pending,
      );

      updatePreviousYear(
        assesseeIndex: assesseeIndex,
        yearIndex: yearIndex,
        value: failed,
      );
    }
  }

  void removePdf({required int assesseeIndex, required int yearIndex}) {
    final current = assessees[assesseeIndex].previousYears[yearIndex];

    updatePreviousYear(
      assesseeIndex: assesseeIndex,
      yearIndex: yearIndex,
      value: PreviousYearFilingInput(
        financialYear: current.financialYear,
        assessmentYear: current.assessmentYear,
        filed: current.filed,
      ),
    );
  }

  Form10IEAResult analyse({
    required int assesseeIndex,
    required List<Form10IEAScenarioRule> rules,
  }) {
    final input = assessees[assesseeIndex];

    final result = _ruleEngine.evaluate(
      input: input,
      rules: rules,
      yearConfig: Form10IEAFinancialYearConfig.current,
    );

    results[input.temporaryId] = result;
    notifyListeners();
    return result;
  }

  Future<String> saveAssessment({
    required int assesseeIndex,
    required List<Form10IEAScenarioRule> rules,
    required String userUid,
  }) async {
    final input = assessees[assesseeIndex];
    final result = results[input.temporaryId];

    if (result == null) {
      throw StateError('Run analysis before saving.');
    }

    isSaving = true;
    notifyListeners();

    try {
      return await repository.saveAssessment(
        input: input,
        clientResult: result,
        rules: rules,
        userUid: userUid,
        idempotencyKey: '${input.temporaryId}_${result.status.name}',
      );
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
