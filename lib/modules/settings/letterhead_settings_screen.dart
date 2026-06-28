import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

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

class _LetterheadSettingsScreenState extends State<LetterheadSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _domestic = _QuotationSettingForm.domestic();
  final _export = _QuotationSettingForm.export();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  DocumentReference<Map<String, dynamic>> get _settingsRef => FirebaseFirestore
      .instance
      .collection('companies')
      .doc(widget.companyId)
      .collection('settings')
      .doc('letterhead_settings');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _domestic.dispose();
    _export.dispose();
    super.dispose();
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

      final domestic = data['domestic'];
      final export = data['export'];

      if (domestic is Map) {
        _domestic.load(Map<String, dynamic>.from(domestic));
      }
      if (export is Map) {
        _export.load(Map<String, dynamic>.from(export));
      }
    } catch (e) {
      _snack('Unable to load quotation settings: $e', isError: true);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _uploadLetterhead(String type) async {
    final form = type == 'domestic' ? _domestic : _export;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final Uint8List? bytes = file.bytes;
    final ext = (file.extension ?? '').toLowerCase();

    if (bytes == null) {
      _snack('File not readable. Please select again.', isError: true);
      return;
    }

    if (!['png', 'jpg', 'jpeg', 'pdf'].contains(ext)) {
      _snack('Only PNG, JPG, JPEG or PDF allowed.', isError: true);
      return;
    }

    setState(() => _uploading = true);

    try {
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path =
          'companies/${widget.companyId}/letterhead_settings/$type/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final ref = FirebaseStorage.instance.ref(path);

      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: ext == 'pdf'
              ? 'application/pdf'
              : ext == 'png'
              ? 'image/png'
              : 'image/jpeg',
        ),
      );

      final url = await ref.getDownloadURL();

      setState(() {
        form.letterheadUrl = url;
        form.letterheadFileName = file.name;
        form.letterheadFileType = ext;
      });

      if (ext == 'pdf') {
        _snack('PDF saved. PNG/JPG is recommended for direct PDF background.');
      } else {
        _snack('Letterhead uploaded.');
      }
    } catch (e) {
      _snack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      await _settingsRef.set({
        'domestic': _domestic.toMap(),
        'export': _export.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': widget.currentUserUid,
        'updatedByName': widget.currentUserName,
      }, SetOptions(merge: true));

      _snack('Quotation settings saved.');
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
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _form(String type, _QuotationSettingForm form) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type == 'domestic'
                ? 'Domestic Letterhead Settings'
                : 'Export Letterhead Settings',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      form.letterheadFileName.isEmpty
                          ? 'No letterhead uploaded'
                          : '${form.letterheadFileName} (${form.letterheadFileType.toUpperCase()})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _uploadLetterhead(type),
                    icon: const Icon(Icons.upload_file),
                    label: Text(_uploading ? 'Uploading...' : 'Upload'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Print Positions',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _numberField(form.dateX, 'Date X'),
              const SizedBox(width: 10),
              _numberField(form.dateY, 'Date Y'),
              const SizedBox(width: 10),
              _numberField(form.dateFontSize, 'Date Font'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _numberField(form.quoteNoX, 'Quote No X'),
              const SizedBox(width: 10),
              _numberField(form.quoteNoY, 'Quote No Y'),
              const SizedBox(width: 10),
              _numberField(form.quoteNoFontSize, 'Quote Font'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Default Terms & Conditions',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => form.terms.add(_Term.blank())),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < form.terms.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: form.terms[i].title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: form.terms[i].value,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      final removed = form.terms.removeAt(i);
                      removed.dispose();
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Letterhead Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Domestic'),
            Tab(text: 'Export'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_form('domestic', _domestic), _form('export', _export)],
      ),
    );
  }
}

class _QuotationSettingForm {
  String letterheadUrl = '';
  String letterheadFileName = '';
  String letterheadFileType = '';

  final TextEditingController dateX;
  final TextEditingController dateY;
  final TextEditingController dateFontSize;
  final TextEditingController quoteNoX;
  final TextEditingController quoteNoY;
  final TextEditingController quoteNoFontSize;
  final List<_Term> terms;

  _QuotationSettingForm({
    required this.dateX,
    required this.dateY,
    required this.dateFontSize,
    required this.quoteNoX,
    required this.quoteNoY,
    required this.quoteNoFontSize,
    required this.terms,
  });

  factory _QuotationSettingForm.domestic() => _QuotationSettingForm(
    dateX: TextEditingController(text: '430'),
    dateY: TextEditingController(text: '98'),
    dateFontSize: TextEditingController(text: '10'),
    quoteNoX: TextEditingController(text: '80'),
    quoteNoY: TextEditingController(text: '98'),
    quoteNoFontSize: TextEditingController(text: '10'),
    terms: [
      _Term('Payment', '100% advance / as mutually agreed'),
      _Term('Delivery', 'As per stock availability'),
      _Term('Validity', '30 days'),
      _Term('Warranty', 'As per company policy'),
    ],
  );

  factory _QuotationSettingForm.export() => _QuotationSettingForm(
    dateX: TextEditingController(text: '430'),
    dateY: TextEditingController(text: '98'),
    dateFontSize: TextEditingController(text: '10'),
    quoteNoX: TextEditingController(text: '80'),
    quoteNoY: TextEditingController(text: '98'),
    quoteNoFontSize: TextEditingController(text: '10'),
    terms: [
      _Term('Payment', 'Advance / LC / CAD as mutually agreed'),
      _Term('Delivery', 'Ex-works / FOB / CIF as per offer'),
      _Term('Validity', '30 days'),
      _Term('Warranty', 'As per agreed export terms'),
      _Term('Packing', 'Export-worthy packing if applicable'),
    ],
  );

  void load(Map<String, dynamic> data) {
    letterheadUrl = (data['letterheadUrl'] ?? '').toString();
    letterheadFileName = (data['letterheadFileName'] ?? '').toString();
    letterheadFileType = (data['letterheadFileType'] ?? '').toString();

    dateX.text = (data['dateX'] ?? dateX.text).toString();
    dateY.text = (data['dateY'] ?? dateY.text).toString();
    dateFontSize.text = (data['dateFontSize'] ?? dateFontSize.text).toString();
    quoteNoX.text = (data['quoteNoX'] ?? quoteNoX.text).toString();
    quoteNoY.text = (data['quoteNoY'] ?? quoteNoY.text).toString();
    quoteNoFontSize.text = (data['quoteNoFontSize'] ?? quoteNoFontSize.text)
        .toString();

    final rawTerms = data['terms'];
    if (rawTerms is List) {
      for (final term in terms) {
        term.dispose();
      }
      terms.clear();

      for (final item in rawTerms) {
        if (item is Map) {
          terms.add(
            _Term(
              (item['title'] ?? '').toString(),
              (item['value'] ?? '').toString(),
            ),
          );
        }
      }
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'letterheadUrl': letterheadUrl,
      'letterheadFileName': letterheadFileName,
      'letterheadFileType': letterheadFileType,
      'dateX': double.tryParse(dateX.text.trim()) ?? 0,
      'dateY': double.tryParse(dateY.text.trim()) ?? 0,
      'dateFontSize': double.tryParse(dateFontSize.text.trim()) ?? 10,
      'quoteNoX': double.tryParse(quoteNoX.text.trim()) ?? 0,
      'quoteNoY': double.tryParse(quoteNoY.text.trim()) ?? 0,
      'quoteNoFontSize': double.tryParse(quoteNoFontSize.text.trim()) ?? 10,
      'terms': terms
          .map((e) => e.toMap())
          .where(
            (e) =>
                e['title'].toString().isNotEmpty ||
                e['value'].toString().isNotEmpty,
          )
          .toList(),
    };
  }

  void dispose() {
    dateX.dispose();
    dateY.dispose();
    dateFontSize.dispose();
    quoteNoX.dispose();
    quoteNoY.dispose();
    quoteNoFontSize.dispose();

    for (final term in terms) {
      term.dispose();
    }
  }
}

class _Term {
  final TextEditingController title;
  final TextEditingController value;

  _Term(String titleText, String valueText)
    : title = TextEditingController(text: titleText),
      value = TextEditingController(text: valueText);

  factory _Term.blank() => _Term('', '');

  Map<String, dynamic> toMap() {
    return {'title': title.text.trim(), 'value': value.text.trim()};
  }

  void dispose() {
    title.dispose();
    value.dispose();
  }
}
