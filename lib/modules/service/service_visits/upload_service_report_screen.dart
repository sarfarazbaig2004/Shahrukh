// FILE PATH: lib/modules/service/service_visits/upload_service_report_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

String _safeString(dynamic val) {
  return (val ?? '').toString().trim();
}

class _LocalUploadFile {
  final String category;
  final String fileName;
  final String fileType;
  final Uint8List? bytes;
  final File? localFile;

  _LocalUploadFile({
    required this.category,
    required this.fileName,
    required this.fileType,
    this.bytes,
    this.localFile,
  });
}

// ==========================================
// MAIN SCREEN
// ==========================================

class UploadServiceReportScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String visitId;
  final Map<String, dynamic> visitData;

  const UploadServiceReportScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.visitId,
    required this.visitData,
  });

  @override
  State<UploadServiceReportScreen> createState() => _UploadServiceReportScreenState();
}

class _UploadServiceReportScreenState extends State<UploadServiceReportScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final List<_LocalUploadFile> _selectedFiles = [];

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusText = '';

  // --- CORE UI DATA ---
  late String _visitNo;
  late String _customerName;
  late String _assignedTechnician;
  late String _status;

  @override
  void initState() {
    super.initState();
    _visitNo = _safeString(widget.visitData['visitNo']);
    _customerName = _safeString(widget.visitData['customerName']);
    _assignedTechnician = _safeString(widget.visitData['assignedTechnicianName']).isNotEmpty
        ? _safeString(widget.visitData['assignedTechnicianName'])
        : _safeString(widget.visitData['engineerName']);
    _status = _safeString(widget.visitData['visitStatus']);
  }

  // ==========================================
  // FILE SELECTION LOGIC
  // ==========================================

  Future<void> _pickImage(String category, ImageSource source) async {
    try {
      final List<XFile> pickedFiles = [];

      if (source == ImageSource.camera) {
        final XFile? photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 70, // Built-in compression
        );
        if (photo != null) pickedFiles.add(photo);
      } else {
        final List<XFile> photos = await _imagePicker.pickMultiImage(
          imageQuality: 70, // Built-in compression
        );
        pickedFiles.addAll(photos);
      }

      for (var xFile in pickedFiles) {
        final bytes = await xFile.readAsBytes();
        final ext = xFile.name.split('.').last.toLowerCase();
        setState(() {
          _selectedFiles.add(_LocalUploadFile(
            category: category,
            fileName: xFile.name,
            fileType: ['jpg', 'jpeg', 'png'].contains(ext) ? 'image' : ext,
            bytes: bytes,
            localFile: kIsWeb ? null : File(xFile.path),
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selecting image: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _pickDocument(String category) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null) {
        for (var file in result.files) {
          final ext = file.extension?.toLowerCase() ?? '';
          setState(() {
            _selectedFiles.add(_LocalUploadFile(
              category: category,
              fileName: file.name,
              fileType: ext == 'pdf' ? 'pdf' : 'image',
              bytes: file.bytes,
              localFile: (!kIsWeb && file.path != null) ? File(file.path!) : null,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selecting document: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  // ==========================================
  // UPLOAD & SAVE LOGIC
  // ==========================================

  Future<void> _submitReport() async {
    final reportFiles = _selectedFiles.where((f) => f.category == 'report').toList();
    if (reportFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least 1 Handwritten Report Photo is required.'), backgroundColor: Colors.red));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Visit?'),
        content: const Text('Are you sure you want to upload these files and mark this visit as Completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.green), child: const Text('Yes, Complete Visit')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusText = 'Initializing upload...';
    });

    final storageRef = FirebaseStorage.instance.ref().child('companies/${widget.companyId}/service_reports/${widget.visitId}');

    List<Map<String, dynamic>> uploadedReports = [];
    List<Map<String, dynamic>> uploadedMachines = [];
    List<Map<String, dynamic>> uploadedSignatures = [];
    List<Map<String, dynamic>> uploadedDocuments = [];

    int successCount = 0;
    int totalFiles = _selectedFiles.length;

    for (int i = 0; i < totalFiles; i++) {
      final file = _selectedFiles[i];
      setState(() {
        _uploadStatusText = 'Uploading file ${i + 1} of $totalFiles...';
        _uploadProgress = i / totalFiles;
      });

      try {
        final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
        final safeName = file.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9\.]'), '_');
        final fullPath = '${file.category}_${uniqueId}_$safeName';
        final fileRef = storageRef.child(fullPath);

        TaskSnapshot snapshot;
        if (file.bytes != null) {
          snapshot = await fileRef.putData(file.bytes!);
        } else if (file.localFile != null) {
          snapshot = await fileRef.putFile(file.localFile!);
        } else {
          continue; // Skip if no data
        }

        final downloadUrl = await snapshot.ref.getDownloadURL();

        final fileRecord = {
          'url': downloadUrl,
          'fileName': file.fileName,
          'fileType': file.fileType,
          'category': file.category,
          'uploadedAt': FieldValue.serverTimestamp(),
          'uploadedByUid': widget.currentUserUid,
          'uploadedByName': widget.currentUserName,
        };

        if (file.category == 'report') uploadedReports.add(fileRecord);
        else if (file.category == 'machine_photo') uploadedMachines.add(fileRecord);
        else if (file.category == 'customer_signature') uploadedSignatures.add(fileRecord);
        else if (file.category == 'document') uploadedDocuments.add(fileRecord);

        successCount++;
      } catch (e) {
        debugPrint('Upload failed for ${file.fileName}: $e');
        // Continue to next file, skipping failed ones
      }
    }

    setState(() {
      _uploadStatusText = 'Saving records...';
      _uploadProgress = 0.95;
    });

    try {
      final db = FirebaseFirestore.instance;
      final visitRef = db.collection('companies').doc(widget.companyId).collection('service_visits').doc(widget.visitId);
      final reqId = _safeString(widget.visitData['requestId']);

      await db.runTransaction((transaction) async {
        // 1. UPDATE VISIT
        final visitUpdates = <String, dynamic>{
          'visitStatus': 'Completed',
          'completedAt': FieldValue.serverTimestamp(),
          'reportSubmittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': widget.currentUserUid,
        };

        if (uploadedReports.isNotEmpty) visitUpdates['reportImages'] = FieldValue.arrayUnion(uploadedReports);
        if (uploadedMachines.isNotEmpty) visitUpdates['machinePhotos'] = FieldValue.arrayUnion(uploadedMachines);
        if (uploadedSignatures.isNotEmpty) visitUpdates['customerSignatures'] = FieldValue.arrayUnion(uploadedSignatures);
        if (uploadedDocuments.isNotEmpty) visitUpdates['documents'] = FieldValue.arrayUnion(uploadedDocuments);

        transaction.update(visitRef, visitUpdates);

        // 2. UPDATE PARENT REQUEST (Merge True to avoid overwriting)
        if (reqId.isNotEmpty) {
          final reqRef = db.collection('companies').doc(widget.companyId).collection('service_requests').doc(reqId);
          final reqUpdates = <String, dynamic>{
            'status': 'Report Submitted',
            'reportSubmittedAt': FieldValue.serverTimestamp(),
            'lastActivity': 'Report Submitted',
            'lastActivityAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': widget.currentUserUid,
          };
          transaction.set(reqRef, reqUpdates, SetOptions(merge: true));
        }
      });

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatusText = 'Complete!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully uploaded $successCount files and completed visit.'), backgroundColor: Colors.green));
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving to database: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    int reportsCount = _selectedFiles.where((f) => f.category == 'report').length;
    int machinesCount = _selectedFiles.where((f) => f.category == 'machine_photo').length;
    int signaturesCount = _selectedFiles.where((f) => f.category == 'customer_signature').length;
    int documentsCount = _selectedFiles.where((f) => f.category == 'document').length;
    int totalCount = _selectedFiles.length;

    return PopScope(
      canPop: !_isUploading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Row(
            children: [
              const Text('Upload Service Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_visitNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // KPI Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildKpiCard('Report Pages', reportsCount.toString(), Icons.description, Colors.indigo),
                    _buildKpiCard('Machine Photos', machinesCount.toString(), Icons.settings, Colors.orange),
                    _buildKpiCard('Signatures', signaturesCount.toString(), Icons.draw, Colors.purple),
                    _buildKpiCard('Documents', documentsCount.toString(), Icons.folder, Colors.teal),
                    _buildKpiCard('Total Files', totalCount.toString(), Icons.file_present, Colors.blueGrey),
                  ],
                ),
              ),
            ),

            // Header Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.blueGrey.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 6),
                  Text(_customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Icon(Icons.engineering, size: 16, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 6),
                  Text(_assignedTechnician, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            if (_isUploading)
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress, backgroundColor: Colors.grey.shade200, color: Colors.green),
                    const SizedBox(height: 8),
                    Text(_uploadStatusText, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  ],
                ),
              ),

            // Main Content Sections
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUploadSection(
                          title: '1. Handwritten Report Photos *',
                          subtitle: 'Take photos of the physical paper report filled by the technician.',
                          category: 'report',
                          icon: Icons.receipt_long,
                          allowPdf: false,
                        ),
                        const SizedBox(height: 24),
                        _buildUploadSection(
                          title: '2. Machine Photos',
                          subtitle: 'Upload before/after photos of the machine or replaced parts.',
                          category: 'machine_photo',
                          icon: Icons.camera_alt,
                          allowPdf: false,
                        ),
                        const SizedBox(height: 24),
                        _buildUploadSection(
                          title: '3. Customer Signature',
                          subtitle: 'Upload photo of the customer signature if separate from the report.',
                          category: 'customer_signature',
                          icon: Icons.draw,
                          allowPdf: false,
                        ),
                        const SizedBox(height: 24),
                        _buildUploadSection(
                          title: '4. Additional Documents',
                          subtitle: 'Upload any other supporting documents (PDF/Images).',
                          category: 'document',
                          icon: Icons.folder_open,
                          allowPdf: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Save Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _isUploading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _isUploading ? null : _submitReport,
                      style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                      icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                      label: const Text('Complete Visit & Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color.shade700),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11, color: color.shade800, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildUploadSection({
    required String title,
    required String subtitle,
    required String category,
    required IconData icon,
    required bool allowPdf,
  }) {
    final sectionFiles = _selectedFiles.where((f) => f.category == category).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueGrey, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : () => _pickImage(category, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 14),
                    label: const Text('Camera'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : () => allowPdf ? _pickDocument(category) : _pickImage(category, ImageSource.gallery),
                    icon: Icon(allowPdf ? Icons.folder : Icons.photo_library, size: 14),
                    label: Text(allowPdf ? 'Browse' : 'Gallery'),
                  ),
                ],
              )
            ],
          ),
          if (sectionFiles.isNotEmpty) ...[
            const Divider(height: 30),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: sectionFiles.map((f) {
                final globalIndex = _selectedFiles.indexOf(f);
                return _buildFileThumbnail(f, globalIndex);
              }).toList(),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildFileThumbnail(_LocalUploadFile file, int globalIndex) {
    Widget thumbnail;

    if (file.fileType == 'pdf') {
      thumbnail = const Center(child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.red));
    } else if (file.bytes != null) {
      thumbnail = Image.memory(file.bytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (file.localFile != null) {
      thumbnail = Image.file(file.localFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      thumbnail = const Center(child: Icon(Icons.insert_drive_file, size: 40, color: Colors.grey));
    }

    return InkWell(
      onTap: () {
        if (file.fileType != 'pdf') {
          // Open local full screen viewer for images
          final allImages = _selectedFiles.where((f) => f.fileType != 'pdf').toList();
          final localIndex = allImages.indexOf(file);
          if (localIndex != -1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenLocalImageViewer(images: allImages, initialIndex: localIndex)));
          }
        }
      },
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: thumbnail),
          ),
          Positioned(
            top: 4, right: 4,
            child: InkWell(
              onTap: _isUploading ? null : () => _removeFile(globalIndex),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                child: const Icon(Icons.close, size: 14, color: Colors.red),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
              child: Text(file.fileName, style: const TextStyle(color: Colors.white, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// LOCAL FULL SCREEN IMAGE VIEWER
// ==========================================

class _FullScreenLocalImageViewer extends StatefulWidget {
  final List<_LocalUploadFile> images;
  final int initialIndex;

  const _FullScreenLocalImageViewer({required this.images, required this.initialIndex});

  @override
  State<_FullScreenLocalImageViewer> createState() => _FullScreenLocalImageViewerState();
}

class _FullScreenLocalImageViewerState extends State<_FullScreenLocalImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Preview ${_currentIndex + 1} of ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemBuilder: (context, index) {
          final file = widget.images[index];
          Widget imgWidget;
          if (file.bytes != null) {
            imgWidget = Image.memory(file.bytes!, fit: BoxFit.contain);
          } else if (file.localFile != null) {
            imgWidget = Image.file(file.localFile!, fit: BoxFit.contain);
          } else {
            imgWidget = const Icon(Icons.broken_image, color: Colors.white, size: 64);
          }

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(child: imgWidget),
          );
        },
      ),
    );
  }
}