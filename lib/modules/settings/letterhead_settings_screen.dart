// lib/modules/settings/letterhead_settings_screen.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LetterheadSettingsScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const LetterheadSettingsScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<LetterheadSettingsScreen> createState() =>
      _LetterheadSettingsScreenState();
}

class _LetterheadSettingsScreenState extends State<LetterheadSettingsScreen> {
  final _form = _LetterheadSettingForm();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  bool _showGrid = true;
  bool _snapToGrid = true;

  DocumentReference<Map<String, dynamic>> get _settingsRef => FirebaseFirestore
      .instance
      .collection('companies')
      .doc(widget.companyId)
      .collection('settings')
      .doc('letterhead_settings');

  @override
  void initState() {
    super.initState();
    _form.addListener(_onFormUpdated);
    _load();
  }

  @override
  void dispose() {
    _form.removeListener(_onFormUpdated);
    _form.dispose();
    super.dispose();
  }

  void _onFormUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      var snap = await _settingsRef.get();
      var data = snap.data() ?? {};

      if (data.isEmpty) {
        final oldSnap = await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('settings')
            .doc('quotation_settings')
            .get();
        data = oldSnap.data() ?? {};
      }

      if (data.isNotEmpty) {
        _form.load(data);
      }
    } catch (e) {
      _snack('Unable to load document layout settings: $e', isError: true);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _uploadLetterhead() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final Uint8List? bytes = file.bytes;
    final ext = (file.extension ?? 'png').toLowerCase();
    final fileSizeKb = (file.size / 1024).toStringAsFixed(1);

    if (bytes == null || bytes.isEmpty) {
      _snack('File not readable. Please select again.', isError: true);
      return;
    }

    if (!['png', 'jpg', 'jpeg'].contains(ext)) {
      _snack('Only PNG, JPG, or JPEG allowed.', isError: true);
      return;
    }

    setState(() => _uploading = true);

    try {
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path =
          'companies/${widget.companyId}/letterhead_settings/default/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final ref = FirebaseStorage.instance.ref(path);

      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        ),
      );

      final url = await ref.getDownloadURL();

      _form.updateLetterhead(
        url: url,
        fileName: file.name,
        fileType: ext,
        fileSizeKb: fileSizeKb,
        uploadDate: DateTime.now().toIso8601String(),
      );

      _snack('Letterhead uploaded successfully.');
    } catch (e) {
      _snack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _deleteLetterhead() {
    _form.updateLetterhead(
      url: '',
      fileName: '',
      fileType: '',
      fileSizeKb: '',
      uploadDate: '',
    );
    _snack('Letterhead removed. Remember to save.');
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Defaults?'),
        content: const Text(
            'This will reset margins and headers to default A4 specifications. Your background image will remain. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _form.resetDimensions();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Restore Defaults'),
          ),
        ],
      ),
    );
  }

  bool _validateForm() {
    double hh = double.tryParse(_form.headerHeight.text.trim()) ?? 0;
    double fh = double.tryParse(_form.footerHeight.text.trim()) ?? 0;
    double lm = double.tryParse(_form.leftMargin.text.trim()) ?? 0;
    double rm = double.tryParse(_form.rightMargin.text.trim()) ?? 0;

    if (hh < 0 || fh < 0 || lm < 0 || rm < 0) {
      _snack('Dimensions cannot be negative.', isError: true);
      return false;
    }

    if (hh + fh > 742) {
      _snack('Header and Footer combined exceed printable page height.',
          isError: true);
      return false;
    }

    if (lm + rm > 495) {
      _snack('Left and Right margins combined exceed printable page width.',
          isError: true);
      return false;
    }

    return true;
  }

  Future<void> _save() async {
    if (!_validateForm()) return;

    setState(() => _saving = true);

    try {
      await _settingsRef.set({
        'letterheadUrl': _form.letterheadUrl,
        'letterheadFileName': _form.letterheadFileName,
        'letterheadFileType': _form.letterheadFileType,
        'letterheadType': _form.letterheadFileType,
        'letterheadFileSizeKb': _form.letterheadFileSizeKb,
        'letterheadUploadDate': _form.letterheadUploadDate,
        'headerHeight': double.tryParse(_form.headerHeight.text.trim()) ?? 120,
        'footerHeight': double.tryParse(_form.footerHeight.text.trim()) ?? 80,
        'leftMargin': double.tryParse(_form.leftMargin.text.trim()) ?? 40,
        'rightMargin': double.tryParse(_form.rightMargin.text.trim()) ?? 40,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': widget.currentUserUid,
        'updatedByName': widget.currentUserName,
      }, SetOptions(merge: true));

      _snack('Document Layout saved successfully.');
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _stepValue(TextEditingController ctrl, int step) {
    double current = double.tryParse(ctrl.text) ?? 0;
    double next = current + step;
    if (next < 0) next = 0;
    ctrl.text = next.toInt().toString();
    _form.notify();
  }

  Widget _buildNumberField(
      TextEditingController controller,
      String label, {
        required IconData icon,
      }) {
    final double ptValue = double.tryParse(controller.text) ?? 0;
    final double mmValue = ptValue * 0.352778;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (val) => _form.notify(),
                decoration: InputDecoration(
                  prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
                  suffixText: 'pt',
                  suffixStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.bold),
                  isDense: true,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                    BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Column(
              children: [
                InkWell(
                  onTap: () => _stepValue(controller, _snapToGrid ? 10 : 1),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4))),
                    child: const Icon(Icons.arrow_drop_up, size: 16),
                  ),
                ),
                InkWell(
                  onTap: () => _stepValue(controller, _snapToGrid ? -10 : -1),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4))),
                    child: const Icon(Icons.arrow_drop_down, size: 16),
                  ),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '≈ ${mmValue.toStringAsFixed(1)} mm',
          style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF334155)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A)),
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. BACKGROUND SECTION
        _buildCard(
          title: 'Document Background',
          icon: Icons.image_outlined,
          action: _form.letterheadUrl.isNotEmpty
              ? TextButton.icon(
            onPressed: _deleteLetterhead,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Remove'),
            style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700),
          )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_form.letterheadUrl.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            _form.letterheadUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _form.letterheadFileName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_form.letterheadFileType.toUpperCase()} • ${_form.letterheadFileSizeKb} KB',
                              style: TextStyle(
                                  color: Colors.blue.shade800, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadLetterhead,
                  icon: _uploading
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file),
                  label: Text(_uploading
                      ? 'Uploading...'
                      : (_form.letterheadUrl.isNotEmpty
                      ? 'Replace Background'
                      : 'Upload Letterhead (PNG/JPG)')),
                ),
              ),
            ],
          ),
        ),

        // 2. PRINTABLE AREA DIMENSIONS
        _buildCard(
          title: 'Printable Area',
          icon: Icons.crop_free,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(_form.headerHeight, 'Header Height',
                        icon: Icons.vertical_align_top),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberField(_form.footerHeight, 'Footer Height',
                        icon: Icons.vertical_align_bottom),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField(_form.leftMargin, 'Left Margin',
                        icon: Icons.format_align_left),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberField(_form.rightMargin, 'Right Margin',
                        icon: Icons.format_align_right),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. LAYOUT TOOLS
        _buildCard(
          title: 'Layout Tools',
          icon: Icons.grid_on_outlined,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Grid & Rulers',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Display layout guides in preview',
                    style: TextStyle(fontSize: 12)),
                value: _showGrid,
                onChanged: (v) => setState(() => _showGrid = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Snap to Grid',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Step dimensions by 10 points',
                    style: TextStyle(fontSize: 12)),
                value: _snapToGrid,
                onChanged: (v) => setState(() => _snapToGrid = v),
              ),
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore Default Dimensions'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 900;
          final controlPanel = _buildControlPanel();
          final previewPanel = Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: _LivePreviewPanel(
                form: _form,
                showGrid: _showGrid,
                snapToGrid: _snapToGrid,
              ),
            ),
          );

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    child: controlPanel,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(child: previewPanel),
              ],
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                controlPanel,
                SizedBox(
                  height: 600,
                  width: double.infinity,
                  child: previewPanel,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Document Layout Designer',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save Layout'),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

// ============================================================================
// LIVE PREVIEW ENGINE
// ============================================================================

class _LivePreviewPanel extends StatelessWidget {
  final _LetterheadSettingForm form;
  final bool showGrid;
  final bool snapToGrid;

  const _LivePreviewPanel({
    required this.form,
    required this.showGrid,
    required this.snapToGrid,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: form,
      builder: (context, _) {
        double hh = double.tryParse(form.headerHeight.text) ?? 120;
        double fh = double.tryParse(form.footerHeight.text) ?? 80;
        double lm = double.tryParse(form.leftMargin.text) ?? 40;
        double rm = double.tryParse(form.rightMargin.text) ?? 40;

        const double a4Width = 595.0;
        const double a4Height = 842.0;

        hh = hh.clamp(0, a4Height - fh - 100);
        fh = fh.clamp(0, a4Height - hh - 100);
        lm = lm.clamp(0, a4Width - rm - 100);
        rm = rm.clamp(0, a4Width - lm - 100);

        const double rulerSize = 24.0;

        return InteractiveViewer(
          minScale: 0.1,
          maxScale: 3.0,
          boundaryMargin: const EdgeInsets.all(100),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: a4Width + rulerSize,
                height: a4Height + rulerSize,
                child: Stack(
                  children: [
                    // Main A4 Page (Offset by ruler size)
                    Positioned(
                      left: rulerSize,
                      top: rulerSize,
                      width: a4Width,
                      height: a4Height,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(4, 4),
                            )
                          ],
                        ),
                        child: Stack(
                          children: [
                            // 1. Uploaded Background Image
                            if (form.letterheadUrl.isNotEmpty)
                              Positioned.fill(
                                child: Image.network(
                                  form.letterheadUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey, size: 50)),
                                ),
                              ),

                            // 2. Overlays (Header/Footer/Margins)
                            if (showGrid) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: hh,
                                child: Container(
                                  color: Colors.blue.withOpacity(0.15),
                                  alignment: Alignment.center,
                                  child: Text('HEADER\n${hh.toInt()} pt',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade900,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: fh,
                                child: Container(
                                  color: Colors.blue.withOpacity(0.15),
                                  alignment: Alignment.center,
                                  child: Text('FOOTER\n${fh.toInt()} pt',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade900,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Positioned(
                                top: hh,
                                bottom: fh,
                                left: 0,
                                width: lm,
                                child: Container(
                                  color: Colors.orange.withOpacity(0.15),
                                  alignment: Alignment.center,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Text('L-MARGIN ${lm.toInt()} pt',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade900,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: hh,
                                bottom: fh,
                                right: 0,
                                width: rm,
                                child: Container(
                                  color: Colors.orange.withOpacity(0.15),
                                  alignment: Alignment.center,
                                  child: RotatedBox(
                                    quarterTurns: 1,
                                    child: Text('R-MARGIN ${rm.toInt()} pt',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade900,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ],

                            // 3. Grid Lines
                            if (showGrid)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _GridPainter(),
                                ),
                              ),

                            // 4. Generic Document Skeleton (Inside Printable Area)
                            Positioned(
                              top: hh,
                              bottom: fh,
                              left: lm,
                              right: rm,
                              child: _SampleGenericContent(showGrid: showGrid),
                            ),

                            // 5. Interactive Drag Handles
                            if (showGrid) ...[
                              // Header Dragger
                              Positioned(
                                top: hh - 8,
                                left: 0,
                                right: 0,
                                height: 16,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeUpDown,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      double val = hh + details.delta.dy;
                                      if (snapToGrid) val = (val / 10).round() * 10;
                                      val = val.clamp(0, a4Height - fh - 100);
                                      form.headerHeight.text = val.toInt().toString();
                                      form.notify();
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: Container(height: 3, width: 40, color: Colors.blue.shade900),
                                    ),
                                  ),
                                ),
                              ),
                              // Footer Dragger
                              Positioned(
                                bottom: fh - 8,
                                left: 0,
                                right: 0,
                                height: 16,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeUpDown,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      double val = fh - details.delta.dy;
                                      if (snapToGrid) val = (val / 10).round() * 10;
                                      val = val.clamp(0, a4Height - hh - 100);
                                      form.footerHeight.text = val.toInt().toString();
                                      form.notify();
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: Container(height: 3, width: 40, color: Colors.blue.shade900),
                                    ),
                                  ),
                                ),
                              ),
                              // Left Margin Dragger
                              Positioned(
                                top: hh,
                                bottom: fh,
                                left: lm - 8,
                                width: 16,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeLeftRight,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      double val = lm + details.delta.dx;
                                      if (snapToGrid) val = (val / 10).round() * 10;
                                      val = val.clamp(0, a4Width - rm - 100);
                                      form.leftMargin.text = val.toInt().toString();
                                      form.notify();
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: Container(width: 3, height: 40, color: Colors.orange.shade900),
                                    ),
                                  ),
                                ),
                              ),
                              // Right Margin Dragger
                              Positioned(
                                top: hh,
                                bottom: fh,
                                right: rm - 8,
                                width: 16,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeLeftRight,
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      double val = rm - details.delta.dx;
                                      if (snapToGrid) val = (val / 10).round() * 10;
                                      val = val.clamp(0, a4Width - lm - 100);
                                      form.rightMargin.text = val.toInt().toString();
                                      form.notify();
                                    },
                                    child: Container(
                                      color: Colors.transparent,
                                      alignment: Alignment.center,
                                      child: Container(width: 3, height: 40, color: Colors.orange.shade900),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Rulers
                    if (showGrid) ...[
                      Positioned(
                        left: rulerSize,
                        top: 0,
                        width: a4Width,
                        height: rulerSize,
                        child: CustomPaint(
                          painter: _RulerPainter(isHorizontal: true),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: rulerSize,
                        width: rulerSize,
                        height: a4Height,
                        child: CustomPaint(
                          painter: _RulerPainter(isHorizontal: false),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        width: rulerSize,
                        height: rulerSize,
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                                bottom: BorderSide(color: Colors.grey.shade400),
                              )),
                          alignment: Alignment.center,
                          child: const Text('pt',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SampleGenericContent extends StatelessWidget {
  final bool showGrid;
  const _SampleGenericContent({required this.showGrid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: showGrid
          ? BoxDecoration(border: _DashedBorder())
          : null,
      child: Opacity(
        opacity: 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Generic Heading Area
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WireframeBlock(width: 140, height: 28),
                _WireframeBlock(width: 100, height: 16),
              ],
            ),
            const SizedBox(height: 24),

            // Generic Paragraph / Addresses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WireframeBlock(width: 160, height: 12),
                    const SizedBox(height: 8),
                    _WireframeBlock(width: 140, height: 12),
                    const SizedBox(height: 8),
                    _WireframeBlock(width: 120, height: 12),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _WireframeBlock(width: 160, height: 12),
                    const SizedBox(height: 8),
                    _WireframeBlock(width: 140, height: 12),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Generic Table Layout
            Container(
              height: 24,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            _WireframeBlock(width: double.infinity, height: 14),
            const SizedBox(height: 12),
            _WireframeBlock(width: double.infinity, height: 14),
            const SizedBox(height: 12),
            _WireframeBlock(width: double.infinity, height: 14),
            const Spacer(),

            // Generic Totals Section
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _WireframeBlock(width: 150, height: 14),
                  const SizedBox(height: 8),
                  _WireframeBlock(width: 150, height: 14),
                  const SizedBox(height: 8),
                  _WireframeBlock(width: 180, height: 20, color: Colors.grey.shade400),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Generic Signatures / Footer text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WireframeBlock(width: 120, height: 12),
                    const SizedBox(height: 8),
                    _WireframeBlock(width: 200, height: 8),
                    const SizedBox(height: 4),
                    _WireframeBlock(width: 180, height: 8),
                  ],
                ),
                _WireframeBlock(width: 140, height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WireframeBlock extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const _WireframeBlock({required this.width, required this.height, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ============================================================================
// PAINTERS & BORDERS
// ============================================================================

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..strokeWidth = 1;

    for (double i = 0; i <= size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += 50) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RulerPainter extends CustomPainter {
  final bool isHorizontal;
  _RulerPainter({required this.isHorizontal});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.grey.shade100;
    final linePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    final textStyle = TextStyle(color: Colors.grey.shade600, fontSize: 8);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (isHorizontal) {
      canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), linePaint);
      for (double i = 0; i <= size.width; i += 10) {
        bool isMajor = i % 50 == 0;
        double tickHeight = isMajor ? 12 : 6;
        canvas.drawLine(Offset(i, size.height - tickHeight), Offset(i, size.height), linePaint);
        if (isMajor && i > 0) {
          final tp = TextPainter(
              text: TextSpan(text: i.toInt().toString(), style: textStyle),
              textDirection: TextDirection.ltr);
          tp.layout();
          tp.paint(canvas, Offset(i + 2, 2));
        }
      }
    } else {
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), linePaint);
      for (double i = 0; i <= size.height; i += 10) {
        bool isMajor = i % 50 == 0;
        double tickWidth = isMajor ? 12 : 6;
        canvas.drawLine(Offset(size.width - tickWidth, i), Offset(size.width, i), linePaint);
        if (isMajor && i > 0) {
          canvas.save();
          canvas.translate(2, i + 2);
          canvas.rotate(-1.5708);
          final tp = TextPainter(
              text: TextSpan(text: i.toInt().toString(), style: textStyle),
              textDirection: TextDirection.ltr);
          tp.layout();
          tp.paint(canvas, const Offset(0, 0));
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedBorder extends BoxBorder {
  @override
  BorderSide get bottom => BorderSide.none;
  @override
  BorderSide get top => BorderSide.none;
  @override
  BorderSide get left => BorderSide.none;
  @override
  BorderSide get right => BorderSide.none;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  bool get isUniform => true;

  @override
  void paint(
      Canvas canvas,
      Rect rect, {
        TextDirection? textDirection,
        BoxShape shape = BoxShape.rectangle,
        BorderRadius? borderRadius,
      }) {
    final paint = Paint()
      ..color = Colors.green.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()..addRect(rect);
    Path dashPath = Path();

    double dashWidth = 8.0;
    double dashSpace = 6.0;
    double distance = 0.0;

    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}

// ============================================================================
// FORM STATE MANAGEMENT
// ============================================================================

class _LetterheadSettingForm extends ChangeNotifier {
  String letterheadUrl = '';
  String letterheadFileName = '';
  String letterheadFileType = '';
  String letterheadFileSizeKb = '';
  String letterheadUploadDate = '';

  final TextEditingController headerHeight = TextEditingController(text: '120');
  final TextEditingController footerHeight = TextEditingController(text: '80');
  final TextEditingController leftMargin = TextEditingController(text: '40');
  final TextEditingController rightMargin = TextEditingController(text: '40');

  void load(Map<String, dynamic> data) {
    final source = data.containsKey('headerHeight') || data.containsKey('letterheadUrl')
        ? data
        : (data['domestic'] is Map ? data['domestic'] as Map<String, dynamic> : data);

    letterheadUrl = (source['letterheadUrl'] ?? '').toString();
    letterheadFileName = (source['letterheadFileName'] ?? '').toString();
    letterheadFileType = (source['letterheadFileType'] ?? source['letterheadType'] ?? '').toString();
    letterheadFileSizeKb = (source['letterheadFileSizeKb'] ?? '').toString();
    letterheadUploadDate = (source['letterheadUploadDate'] ?? '').toString();

    headerHeight.text = (source['headerHeight'] ?? headerHeight.text).toString();
    footerHeight.text = (source['footerHeight'] ?? footerHeight.text).toString();
    leftMargin.text = (source['leftMargin'] ?? leftMargin.text).toString();
    rightMargin.text = (source['rightMargin'] ?? rightMargin.text).toString();

    notifyListeners();
  }

  void updateLetterhead({
    required String url,
    required String fileName,
    required String fileType,
    required String fileSizeKb,
    required String uploadDate,
  }) {
    letterheadUrl = url;
    letterheadFileName = fileName;
    letterheadFileType = fileType;
    letterheadFileSizeKb = fileSizeKb;
    letterheadUploadDate = uploadDate;
    notifyListeners();
  }

  void resetDimensions() {
    headerHeight.text = '120';
    footerHeight.text = '80';
    leftMargin.text = '40';
    rightMargin.text = '40';
    notifyListeners();
  }

  void notify() => notifyListeners();

  @override
  void dispose() {
    headerHeight.dispose();
    footerHeight.dispose();
    leftMargin.dispose();
    rightMargin.dispose();
    super.dispose();
  }
}