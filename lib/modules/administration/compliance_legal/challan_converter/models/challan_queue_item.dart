import 'dart:typed_data';

class ChallanQueueItem {
  ChallanQueueItem({
    required this.id,
    required this.fileName,
    required this.bytes,
    required this.fileSize,
    this.status = 'Pending',
    this.errorMessage = '',
  });

  final String id;
  final String fileName;
  final Uint8List bytes;
  final int fileSize;

  String status;
  String errorMessage;
}
