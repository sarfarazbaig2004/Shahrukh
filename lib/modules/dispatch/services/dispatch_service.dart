import 'package:cloud_firestore/cloud_firestore.dart';

class DispatchService {
  DispatchService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _salesOrders(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('sales_orders');
  }

  CollectionReference<Map<String, dynamic>> _dispatchChallans(
    String companyId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('dispatch_challans');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> salesOrdersStream({
    required String companyId,
  }) {
    return _salesOrders(
      companyId,
    ).orderBy('createdAt', descending: true).limit(100).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> challansStream({
    required String companyId,
  }) {
    return _dispatchChallans(
      companyId,
    ).orderBy('createdAt', descending: true).limit(150).snapshots();
  }

  Future<String> createDispatchChallan({
    required String companyId,
    required String salesOrderId,
    required String createdBy,
    required String warehouseName,
    required String transporterName,
    required String vehicleNumber,
    required String lrNumber,
    required String packingDetails,
    required String remarks,
  }) async {
    final soRef = _salesOrders(companyId).doc(salesOrderId);
    final challanRef = _dispatchChallans(companyId).doc();
    final challanNo = _generateChallanNumber();

    await _firestore.runTransaction((transaction) async {
      final soSnap = await transaction.get(soRef);
      if (!soSnap.exists) {
        throw Exception('Sales Order not found.');
      }

      final soData = soSnap.data() ?? {};
      final dispatchStatus = (soData['dispatchStatus'] ?? 'pending')
          .toString()
          .toLowerCase();

      if (dispatchStatus == 'delivered') {
        throw Exception('This order is already delivered.');
      }

      transaction.set(challanRef, {
        'companyId': companyId,
        'dispatchChallanNumber': challanNo,
        'salesOrderId': salesOrderId,
        'salesOrderNumber':
            soData['salesOrderNumber'] ??
            soData['soNumber'] ??
            soData['orderNumber'] ??
            '',
        'customerId': soData['customerId'] ?? '',
        'customerName':
            soData['customerName'] ??
            soData['clientName'] ??
            soData['partyName'] ??
            '',
        'grandTotal': _toDouble(
          soData['grandTotal'] ?? soData['totalAmount'] ?? soData['amount'],
        ),
        'items': soData['items'] ?? soData['products'] ?? [],
        'warehouseName': warehouseName.trim(),
        'transporterName': transporterName.trim(),
        'vehicleNumber': vehicleNumber.trim().toUpperCase(),
        'lrNumber': lrNumber.trim(),
        'packingDetails': packingDetails.trim(),
        'remarks': remarks.trim(),
        'status': 'challan_created',
        'statusLabel': 'Challan Created',
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(soRef, {
        'dispatchStatus': 'challan_created',
        'dispatchChallanId': challanRef.id,
        'dispatchChallanNumber': challanNo,
        'dispatchUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return challanNo;
  }

  Future<void> updateShipment({
    required String companyId,
    required String challanId,
    required String transporterName,
    required String vehicleNumber,
    required String lrNumber,
    required String trackingRemarks,
  }) async {
    final challanRef = _dispatchChallans(companyId).doc(challanId);

    await _firestore.runTransaction((transaction) async {
      final challanSnap = await transaction.get(challanRef);
      if (!challanSnap.exists) {
        throw Exception('Dispatch challan not found.');
      }

      final data = challanSnap.data() ?? {};
      final salesOrderId = (data['salesOrderId'] ?? '').toString();

      transaction.set(challanRef, {
        'transporterName': transporterName.trim(),
        'vehicleNumber': vehicleNumber.trim().toUpperCase(),
        'lrNumber': lrNumber.trim(),
        'trackingRemarks': trackingRemarks.trim(),
        'status': 'in_transit',
        'statusLabel': 'In Transit',
        'shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (salesOrderId.isNotEmpty) {
        transaction.set(_salesOrders(companyId).doc(salesOrderId), {
          'dispatchStatus': 'in_transit',
          'dispatchUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> markDelivered({
    required String companyId,
    required String challanId,
    required String deliveredTo,
    required String podRemarks,
  }) async {
    final challanRef = _dispatchChallans(companyId).doc(challanId);

    await _firestore.runTransaction((transaction) async {
      final challanSnap = await transaction.get(challanRef);
      if (!challanSnap.exists) {
        throw Exception('Dispatch challan not found.');
      }

      final data = challanSnap.data() ?? {};
      final salesOrderId = (data['salesOrderId'] ?? '').toString();

      transaction.set(challanRef, {
        'status': 'delivered',
        'statusLabel': 'Delivered',
        'deliveredTo': deliveredTo.trim(),
        'podRemarks': podRemarks.trim(),
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (salesOrderId.isNotEmpty) {
        transaction.set(_salesOrders(companyId).doc(salesOrderId), {
          'dispatchStatus': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
          'dispatchUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  String _generateChallanNumber() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'DC-$date-$time';
  }

  double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
