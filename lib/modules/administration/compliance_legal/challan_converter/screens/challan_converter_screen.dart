import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/modules/administration/compliance_legal/design_system/compliance_design_system.dart';
import '../controllers/challan_converter_controller.dart';
import '../models/challan_extraction_model.dart';
import '../models/challan_queue_item.dart';

class ChallanConverterScreen extends StatefulWidget {
  ChallanConverterScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
    this.canExport = true,
    this.canUpload = true,
    this.canDownload = true,
  });

  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canExport;
  final bool canUpload;
  final bool canDownload;

  @override
  State<ChallanConverterScreen> createState() => _ChallanConverterScreenState();
}

class _ChallanConverterScreenState extends State<ChallanConverterScreen> {
  late final ChallanConverterController _controller;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = ChallanConverterController()..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();

    _searchController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? context.compliance.danger
            : context.compliance.success,
      ),
    );
  }

  Future<void> _runExport(String type) async {
    try {
      switch (type) {
        case 'csv':
          await _controller.exportCsv();
        case 'json':
          await _controller.exportJson();
        case 'selected_csv':
          await _controller.exportCsv(selectedOnly: true);
      }
    } catch (error) {
      _message('Export failed: $error', error: true);
    }
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Challan Converter Help'),
          content: SizedBox(
            width: 580,
            child: Text(
              'This converter processes digital Income Tax, TDS and TCS PDF '
              'challans locally on your device. Files are not uploaded to '
              'Firebase or any remote server.\n\n'
              'Digital PDFs with embedded text are supported. Scanned image '
              'PDFs require an offline OCR engine and will be reported as '
              'unsupported instead of generating fake extracted data.\n\n'
              'Supported recognition includes ITNS 280, 281, 282, 283, '
              'Form 26QB, 26QC, 26QD, Form 27EQ, PAN, TAN, BSR code, '
              'assessment year, financial year, dates and amounts.',
              style: TextStyle(height: 1.5),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showDetails(ChallanExtractionModel record) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: context.compliance.scrim,
      transitionDuration: Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: context.compliance.surface,
            elevation: 14,
            child: SizedBox(
              width: 520,
              height: double.infinity,
              child: SafeArea(
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.sourceFileName,
                                style: TextStyle(
                                  color: context.compliance.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        tabs: [
                          Tab(text: 'Extracted'),
                          Tab(text: 'Validation'),
                          Tab(text: 'PDF Text'),
                          Tab(text: 'Metadata'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            ListView(
                              padding: EdgeInsets.all(18),
                              children: [
                                _detail('Challan Type', record.challanType),
                                _detail('ITNS / Form', record.itnsForm),
                                _detail('PAN', record.pan),
                                _detail('TAN', record.tan),
                                _detail('Name', record.name),
                                _detail(
                                  'Assessment Year',
                                  record.assessmentYear,
                                ),
                                _detail('Financial Year', record.financialYear),
                                _detail('BSR Code', record.bsrCode),
                                _detail(
                                  'Serial Number',
                                  record.challanSerialNumber,
                                ),
                                _detail(
                                  'Deposit Date',
                                  record.depositDate == null
                                      ? ''
                                      : DateFormat(
                                          'dd MMM yyyy',
                                        ).format(record.depositDate!),
                                ),
                                _detail('Major Head', record.majorHead),
                                _detail('Minor Head', record.minorHead),
                                _detail('Section', record.section),
                                _detail(
                                  'Amount',
                                  record.amount.toStringAsFixed(2),
                                ),
                                _detail(
                                  'Interest',
                                  record.interest.toStringAsFixed(2),
                                ),
                                _detail(
                                  'Penalty',
                                  record.penalty.toStringAsFixed(2),
                                ),
                                _detail(
                                  'Late Fee',
                                  record.lateFee.toStringAsFixed(2),
                                ),
                                _detail(
                                  'Total Amount',
                                  record.totalAmount.toStringAsFixed(2),
                                ),
                                _detail('Bank', record.bankName),
                                _detail('Branch', record.branch),
                              ],
                            ),
                            ListView(
                              padding: EdgeInsets.all(18),
                              children: [
                                _detail(
                                  'Verification',
                                  record.verificationStatus,
                                ),
                                _detail(
                                  'Confidence',
                                  '${record.confidenceScore.toStringAsFixed(1)}%',
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Warnings',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 8),
                                if (record.warnings.isEmpty)
                                  Text('No warnings.')
                                else
                                  ...record.warnings.map(
                                    (warning) => ListTile(
                                      leading: Icon(
                                        Icons.warning_amber,
                                        color: context.compliance.warning,
                                      ),
                                      title: Text(warning),
                                    ),
                                  ),
                                SizedBox(height: 12),
                                Text(
                                  'Errors',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 8),
                                if (record.errors.isEmpty)
                                  Text('No errors.')
                                else
                                  ...record.errors.map(
                                    (error) => ListTile(
                                      leading: Icon(
                                        Icons.error_outline,
                                        color: context.compliance.danger,
                                      ),
                                      title: Text(error),
                                    ),
                                  ),
                              ],
                            ),
                            SingleChildScrollView(
                              padding: EdgeInsets.all(18),
                              child: SelectableText(
                                record.extractedText,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  height: 1.5,
                                ),
                              ),
                            ),
                            ListView(
                              padding: EdgeInsets.all(18),
                              children: [
                                _detail('File Name', record.sourceFileName),
                                _detail(
                                  'File Size',
                                  '${(record.sourceFileSize / 1024).toStringAsFixed(1)} KB',
                                ),
                                _detail('File Hash', record.sourceFileHash),
                                _detail(
                                  'Processing Time',
                                  '${record.processingTimeMilliseconds} ms',
                                ),
                                _detail(
                                  'Created',
                                  DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(record.createdAt),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  Widget _detail(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.compliance.surfaceMuted,
        border: Border.all(color: context.compliance.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: TextStyle(
                color: context.compliance.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: context.compliance.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _controller.visibleRecords;

    return ComplianceSubpageShell(
      title: 'Tax Challan Converter',
      subtitle:
          'Secure local extraction, validation and governed export for Income Tax, TDS and TCS challans',
      icon: Icons.document_scanner_outlined,
      breadcrumbs: const <String>[
        'Administration',
        'Compliance & Legal',
        'Tax Challan Converter',
      ],
      onBack: () => Navigator.maybePop(context),
      padding: EdgeInsets.zero,
      actions: <Widget>[
        OutlinedButton.icon(
          onPressed: widget.canUpload
              ? () => _controller.pickFiles(allowMultiple: false)
              : null,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('Upload PDF'),
        ),
        OutlinedButton.icon(
          onPressed: widget.canUpload
              ? () => _controller.pickFiles(allowMultiple: true)
              : null,
          icon: const Icon(Icons.library_add_outlined, size: 18),
          label: const Text('Bulk Upload'),
        ),
        PopupMenuButton<String>(
          tooltip: 'Export',
          enabled: widget.canExport && _controller.records.isNotEmpty,
          onSelected: _runExport,
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            const PopupMenuItem(value: 'csv', child: Text('Export CSV')),
            const PopupMenuItem(value: 'json', child: Text('Export JSON')),
            if (_controller.selectedRecordIds.isNotEmpty)
              const PopupMenuItem(
                value: 'selected_csv',
                child: Text('Export Selected CSV'),
              ),
          ],
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          tooltip: 'Help',
          onPressed: _showHelp,
          icon: const Icon(Icons.help_outline_rounded),
        ),
      ],
      child: Column(
        children: [
          _buildSummary(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                if (compact) {
                  return Column(
                    children: <Widget>[
                      SizedBox(height: 300, child: _buildQueuePanel()),
                      Divider(height: 1, color: context.compliance.border),
                      Expanded(child: _buildResultsPanel(records)),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(width: 390, child: _buildQueuePanel()),
                    VerticalDivider(width: 1, color: context.compliance.border),
                    Expanded(child: _buildResultsPanel(records)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      color: context.compliance.surface,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _metric(
            'Total Files',
            '${_controller.totalFiles}',
            Icons.folder_outlined,
            context.compliance.primary,
          ),
          _metric(
            'Processed',
            '${_controller.processedFiles}',
            Icons.check_circle_outline,
            context.compliance.success,
          ),
          _metric(
            'Pending',
            '${_controller.pendingFiles}',
            Icons.schedule_outlined,
            context.compliance.warning,
          ),
          _metric(
            'Failed',
            '${_controller.failedFiles}',
            Icons.error_outline,
            context.compliance.danger,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(_controller.progress * 100).toStringAsFixed(0)}% complete',
                    style: TextStyle(
                      color: context.compliance.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: _controller.progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.compliance.surface,
        border: Border.all(color: context.compliance.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.compliance.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: context.compliance.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueuePanel() {
    return Container(
      color: context.compliance.surfaceMuted,
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.canUpload
                ? () => _controller.pickFiles(allowMultiple: true)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: context.compliance.surface,
                border: Border.all(
                  color: context.compliance.primary,
                  width: 1.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 42,
                    color: context.compliance.primary,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Select Challan PDFs',
                    style: TextStyle(
                      color: context.compliance.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Single or multiple digital PDF files\nMaximum 500 files',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.compliance.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              FilledButton.icon(
                onPressed:
                    !_controller.isProcessing && _controller.queue.isNotEmpty
                    ? _controller.processQueue
                    : null,
                icon: Icon(Icons.play_arrow),
                label: Text('Process Queue'),
              ),
              OutlinedButton(
                onPressed: _controller.isProcessing && !_controller.isPaused
                    ? _controller.pause
                    : null,
                child: Text('Pause'),
              ),
              OutlinedButton(
                onPressed: _controller.isProcessing && _controller.isPaused
                    ? _controller.resume
                    : null,
                child: Text('Resume'),
              ),
              OutlinedButton(
                onPressed: _controller.isProcessing ? _controller.cancel : null,
                child: Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: _controller.failedFiles > 0
                    ? _controller.retryFailed
                    : null,
                child: Text('Retry Failed'),
              ),
              OutlinedButton(
                onPressed: !_controller.isProcessing
                    ? _controller.clearCompleted
                    : null,
                child: Text('Clear Completed'),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Processing Queue',
            style: TextStyle(
              color: context.compliance.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: _controller.queue.isEmpty
                ? Center(
                    child: Text(
                      'No PDFs selected.',
                      style: TextStyle(color: context.compliance.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: _controller.queue.length,
                    separatorBuilder: (_, __) => SizedBox(height: 7),
                    itemBuilder: (_, index) {
                      return _queueItem(_controller.queue[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _queueItem(ChallanQueueItem item) {
    final statusColor = switch (item.status) {
      'Processed' => context.compliance.success,
      'Failed' => context.compliance.danger,
      'Processing' => context.compliance.primary,
      _ => context.compliance.warning,
    };

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.compliance.surface,
        border: Border.all(color: context.compliance.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf_outlined, color: context.compliance.danger),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.compliance.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${(item.fileSize / 1024).toStringAsFixed(1)} KB • ${item.status}',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.errorMessage.isNotEmpty)
                  Text(
                    item.errorMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.compliance.danger,
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: !_controller.isProcessing
                ? () => _controller.removeQueueItem(item.id)
                : null,
            icon: Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPanel(List<ChallanExtractionModel> records) {
    return Column(
      children: [
        Container(
          color: context.compliance.surface,
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _controller.search = value;
                    _controller.currentPage = 0;
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search extracted data...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(width: 10),
              _dropdown(
                value: _controller.verificationFilter,
                values: const ['All', 'Valid', 'Warning', 'Error'],
                label: 'Verification',
                onChanged: (value) {
                  _controller.verificationFilter = value;
                  _controller.currentPage = 0;
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              SizedBox(width: 10),
              _dropdown(
                value: _controller.challanTypeFilter,
                values: const [
                  'All',
                  'Income Tax',
                  'TDS',
                  'TCS',
                  'Advance Tax',
                  'Self Assessment Tax',
                  'Regular Assessment Tax',
                ],
                label: 'Type',
                onChanged: (value) {
                  _controller.challanTypeFilter = value;
                  _controller.currentPage = 0;
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              Spacer(),
              if (_controller.selectedRecordIds.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: widget.canDelete
                      ? _controller.deleteSelected
                      : null,
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.compliance.danger,
                  ),
                  label: Text(
                    'Delete ${_controller.selectedRecordIds.length}',
                    style: TextStyle(color: context.compliance.danger),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text(
                    'Process a digital challan PDF to view extracted data.',
                    style: TextStyle(color: context.compliance.textSecondary),
                  ),
                )
              : _buildTable(records),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> values,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return ComplianceSelector<String>(
      label: label,
      valueLabel: value,
      options: values,
      labelBuilder: (item) => item,
      onSelected: onChanged,
      searchHint: 'Search $label',
      icon: Icons.filter_alt_outlined,
      width: 178,
    );
  }

  Widget _buildTable(List<ChallanExtractionModel> records) {
    return Padding(
      padding: EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          color: context.compliance.surface,
          border: Border.all(color: context.compliance.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 2600,
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (_, index) {
                        return _row(records[index], index);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: context.compliance.primaryHover,
      child: Row(
        children: [
          _TableHeader('', 48),
          _TableHeader('#', 50),
          _TableHeader('STATUS', 110),
          _TableHeader('TYPE', 130),
          _TableHeader('ITNS / FORM', 120),
          _TableHeader('PAN', 120),
          _TableHeader('TAN', 120),
          _TableHeader('NAME', 180),
          _TableHeader('ASSESSMENT YEAR', 125),
          _TableHeader('FINANCIAL YEAR', 125),
          _TableHeader('BSR CODE', 100),
          _TableHeader('SERIAL NUMBER', 125),
          _TableHeader('DEPOSIT DATE', 120),
          _TableHeader('MAJOR HEAD', 100),
          _TableHeader('MINOR HEAD', 100),
          _TableHeader('SECTION', 100),
          _TableHeader('AMOUNT', 110),
          _TableHeader('INTEREST', 100),
          _TableHeader('PENALTY', 100),
          _TableHeader('LATE FEE', 100),
          _TableHeader('TOTAL', 115),
          _TableHeader('BANK', 160),
          _TableHeader('VERIFICATION', 120),
          _TableHeader('ACTIONS', 120),
        ],
      ),
    );
  }

  Widget _row(ChallanExtractionModel record, int index) {
    return InkWell(
      onTap: () => _showDetails(record),
      child: Container(
        color: index.isEven
            ? context.compliance.surface
            : context.compliance.surfaceMuted,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Checkbox(
                value: _controller.selectedRecordIds.contains(record.id),
                onChanged: (selected) {
                  _controller.toggleRecordSelection(
                    record.id,
                    selected == true,
                  );
                },
              ),
            ),
            _cell('${index + 1}', 50),
            _cell(record.status, 110),
            _cell(record.challanType, 130),
            _cell(record.itnsForm, 120),
            _cell(record.pan, 120),
            _cell(record.tan, 120),
            _cell(record.name, 180),
            _cell(record.assessmentYear, 125),
            _cell(record.financialYear, 125),
            _cell(record.bsrCode, 100),
            _cell(record.challanSerialNumber, 125),
            _cell(
              record.depositDate == null
                  ? ''
                  : DateFormat('dd MMM yyyy').format(record.depositDate!),
              120,
            ),
            _cell(record.majorHead, 100),
            _cell(record.minorHead, 100),
            _cell(record.section, 100),
            _cell(record.amount.toStringAsFixed(2), 110),
            _cell(record.interest.toStringAsFixed(2), 100),
            _cell(record.penalty.toStringAsFixed(2), 100),
            _cell(record.lateFee.toStringAsFixed(2), 100),
            _cell(record.totalAmount.toStringAsFixed(2), 115, strong: true),
            _cell(record.bankName, 160),
            _verificationCell(record.verificationStatus, 120),
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'View',
                    onPressed: () => _showDetails(record),
                    icon: Icon(Icons.visibility_outlined, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.canDelete
                        ? () => _controller.deleteRecord(record.id)
                        : null,
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.compliance.danger,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String value, double width, {bool strong = false}) {
    return Tooltip(
      message: value,
      child: Container(
        width: width,
        constraints: BoxConstraints(minHeight: 58),
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: context.compliance.border),
            bottom: BorderSide(color: context.compliance.border),
          ),
        ),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.compliance.textPrimary,
            fontSize: 10.5,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _verificationCell(String value, double width) {
    final color = switch (value) {
      'Valid' => context.compliance.success,
      'Error' => context.compliance.danger,
      _ => context.compliance.warning,
    };

    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label, this.width);

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: context.compliance.primaryHover),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.compliance.surface,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
