import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class QuotationSettingsScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const QuotationSettingsScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<QuotationSettingsScreen> createState() =>
      _QuotationSettingsScreenState();
}

class _QuotationSettingsScreenState extends State<QuotationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String _activeType = 'domestic';

  final _domestic = _LetterheadForm.defaults();
  final _export = _LetterheadForm.defaults();

  DocumentReference<Map<String, dynamic>> get _settingsRef => FirebaseFirestore
      .instance
      .collection('companies')
      .doc(widget.companyId)
      .collection('settings')
      .doc('letterhead_settings');

  _LetterheadForm get _currentForm =>
      _activeType == 'export' ? _export : _domestic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _domestic.dispose();
    _export.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _settingsRef.get();
      final data = snap.data() ?? {};

      if (data['domestic'] is Map) {
        _domestic.load(Map<String, dynamic>.from(data['domestic']));
      }
      if (data['export'] is Map) {
        _export.load(Map<String, dynamic>.from(data['export']));
      }

      // Backward compatibility if old settings were stored flat.
      if (data['letterheadUrl'] != null) {
        _domestic.load(data);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadLetterhead() async {
    final form = _currentForm;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() => _saving = true);

    try {
      final ext = (file.extension ?? 'png').toLowerCase();
      final fileName =
          '${_activeType}_letterhead_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final ref = FirebaseStorage.instance.ref().child(
        'companies/${widget.companyId}/quotation_letterheads/$fileName',
      );

      final contentType = ext == 'jpg' || ext == 'jpeg'
          ? 'image/jpeg'
          : 'image/png';

      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      final url = await ref.getDownloadURL();

      form.letterheadUrl = url;
      form.letterheadType = ext;

      await _save(showMessage: false);

      if (!mounted) return;
      _snack('Letterhead uploaded successfully.');
    } catch (e) {
      _snack('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save({bool showMessage = true}) async {
    setState(() => _saving = true);

    try {
      await _settingsRef.set({
        'domestic': _domestic.toMap(),
        'export': _export.toMap(),

        // Keep flat keys for older PDF code compatibility.
        'letterheadUrl': _domestic.letterheadUrl,
        'letterheadType': _domestic.letterheadType,
        'dateX': double.tryParse(_domestic.dateX.text.trim()) ?? 430,
        'dateY': double.tryParse(_domestic.dateY.text.trim()) ?? 98,
        'dateFontSize':
            double.tryParse(_domestic.dateFontSize.text.trim()) ?? 10,
        'quoteNoX': double.tryParse(_domestic.quoteNoX.text.trim()) ?? 80,
        'quoteNoY': double.tryParse(_domestic.quoteNoY.text.trim()) ?? 98,
        'quoteNoFontSize':
            double.tryParse(_domestic.quoteNoFontSize.text.trim()) ?? 10,
        'terms': _domestic.terms.text.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': widget.currentUserUid,
        'updatedByName': widget.currentUserName,
      }, SetOptions(merge: true));

      if (showMessage) _snack('Quotation settings saved.');
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = _currentForm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation Settings'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Letterhead Options',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Upload quotation letterhead once. Quotation PDF will print only text and tables on it.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'domestic',
                        label: Text('Domestic Quotation'),
                        icon: Icon(Icons.receipt_long_outlined),
                      ),
                      ButtonSegment(
                        value: 'export',
                        label: Text('Export Quotation'),
                        icon: Icon(Icons.flight_takeoff_outlined),
                      ),
                    ],
                    selected: {_activeType},
                    onSelectionChanged: (set) {
                      setState(() => _activeType = set.first);
                    },
                  ),
                  const SizedBox(height: 18),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _activeType == 'export'
                                      ? 'Export Letterhead'
                                      : 'Domestic Letterhead',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _saving ? null : _uploadLetterhead,
                                icon: const Icon(Icons.upload_file_outlined),
                                label: const Text('Upload Letterhead'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (form.letterheadUrl.trim().isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Letterhead uploaded (${form.letterheadType.toUpperCase()})',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                'No letterhead uploaded yet. Use PNG/JPG only.',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          const Text(
                            'Print Position Settings',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _numField(form.quoteNoX, 'Quote No X'),
                              const SizedBox(width: 10),
                              _numField(form.quoteNoY, 'Quote No Y'),
                              const SizedBox(width: 10),
                              _numField(form.quoteNoFontSize, 'Quote Font'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _numField(form.dateX, 'Date X'),
                              const SizedBox(width: 10),
                              _numField(form.dateY, 'Date Y'),
                              const SizedBox(width: 10),
                              _numField(form.dateFontSize, 'Date Font'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: form.terms,
                            maxLines: 7,
                            decoration: const InputDecoration(
                              labelText: 'Default Terms & Conditions',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _numField(TextEditingController controller, String label) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _LetterheadForm {
  String letterheadUrl = '';
  String letterheadType = '';
  final TextEditingController dateX;
  final TextEditingController dateY;
  final TextEditingController dateFontSize;
  final TextEditingController quoteNoX;
  final TextEditingController quoteNoY;
  final TextEditingController quoteNoFontSize;
  final TextEditingController terms;

  _LetterheadForm({
    required this.dateX,
    required this.dateY,
    required this.dateFontSize,
    required this.quoteNoX,
    required this.quoteNoY,
    required this.quoteNoFontSize,
    required this.terms,
  });

  factory _LetterheadForm.defaults() {
    return _LetterheadForm(
      dateX: TextEditingController(text: '430'),
      dateY: TextEditingController(text: '98'),
      dateFontSize: TextEditingController(text: '10'),
      quoteNoX: TextEditingController(text: '80'),
      quoteNoY: TextEditingController(text: '98'),
      quoteNoFontSize: TextEditingController(text: '10'),
      terms: TextEditingController(
        text:
            'Payment: 100% advance\nDelivery: Within 2-3 weeks from PO and advance\nValidity: 30 days from date of quotation\nWarranty: 12 months from date of dispatch on Power Source only',
      ),
    );
  }

  void load(Map<String, dynamic> data) {
    letterheadUrl = (data['letterheadUrl'] ?? '').toString();
    letterheadType = (data['letterheadType'] ?? '').toString();
    dateX.text = (data['dateX'] ?? dateX.text).toString();
    dateY.text = (data['dateY'] ?? dateY.text).toString();
    dateFontSize.text = (data['dateFontSize'] ?? dateFontSize.text).toString();
    quoteNoX.text = (data['quoteNoX'] ?? quoteNoX.text).toString();
    quoteNoY.text = (data['quoteNoY'] ?? quoteNoY.text).toString();
    quoteNoFontSize.text = (data['quoteNoFontSize'] ?? quoteNoFontSize.text)
        .toString();

    final loadedTerms = data['terms'];
    if (loadedTerms is String && loadedTerms.trim().isNotEmpty) {
      terms.text = loadedTerms;
    } else if (loadedTerms is List) {
      terms.text = loadedTerms
          .map((e) {
            if (e is Map) {
              final title = (e['title'] ?? '').toString();
              final value = (e['value'] ?? '').toString();
              return title.isEmpty ? value : '$title: $value';
            }
            return e.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .join('\n');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'letterheadUrl': letterheadUrl,
      'letterheadType': letterheadType,
      'dateX': double.tryParse(dateX.text.trim()) ?? 430,
      'dateY': double.tryParse(dateY.text.trim()) ?? 98,
      'dateFontSize': double.tryParse(dateFontSize.text.trim()) ?? 10,
      'quoteNoX': double.tryParse(quoteNoX.text.trim()) ?? 80,
      'quoteNoY': double.tryParse(quoteNoY.text.trim()) ?? 98,
      'quoteNoFontSize': double.tryParse(quoteNoFontSize.text.trim()) ?? 10,
      'terms': terms.text.trim(),
    };
  }

  void dispose() {
    dateX.dispose();
    dateY.dispose();
    dateFontSize.dispose();
    quoteNoX.dispose();
    quoteNoY.dispose();
    quoteNoFontSize.dispose();
    terms.dispose();
  }
}
